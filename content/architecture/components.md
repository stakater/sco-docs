# Components

Detailed reference for every component in the Stakater Cloud Orchestrator platform — what each one does, why it is included, and how it integrates with the rest of the system.

---

## Foundation

### Red Hat OpenShift

OpenShift is the management cluster on which all SCO components run. SCO requires OpenShift (rather than vanilla Kubernetes) for several reasons:

- **OpenShift Virtualization** requires bare-metal nodes with hardware virtualisation support, which OpenShift's node management provisions and configures
- **HyperShift** is officially supported and tested on OpenShift
- **OpenShift's operator lifecycle management** (OLM) provides a standardised way to install, update, and manage operators from the Red Hat ecosystem
- **Security Context Constraints** provide a more expressive security model than upstream pod security admission

OpenShift also provides cluster networking (OVN-Kubernetes), persistent storage integration (OpenShift Data Foundation, CSI drivers), an internal image registry, and the `Route` API for exposing services externally.

**Version requirement:** OpenShift 4.14 or later on bare-metal nodes.

---

## Platform Orchestration

### OpenShift GitOps (ArgoCD)

ArgoCD is the GitOps engine that installs and continuously reconciles every platform component. The platform's entire desired state — operators, CRDs, Crossplane compositions, platform configuration — is declared in a Git repository and applied by ArgoCD.

**Role in SCO:**
- Installs all operators via `Subscription` and `OperatorGroup` resources
- Deploys Crossplane and its providers
- Applies platform-level compositions (KCP, Keycloak, MTO, OpenBao)
- Maintains configuration drift correction — any manual change to a platform resource is reverted

**Integration points:** ArgoCD operates at the cluster-admin level and is the first component installed during platform bootstrap. All subsequent components are managed through ArgoCD application resources.

---

## Composition Engine

### Crossplane

Crossplane is the composition and orchestration engine at the heart of SCO. It plays two separate but related roles:

**Role 1: Platform self-management**

SCO is installed and maintained as a Crossplane composition. The `KubeStackPlus` claim applied during installation triggers a composition pipeline that installs and configures KCP, Keycloak, MTO, OpenBao, HyperShift, and all supporting components. Crossplane continuously reconciles this — if any platform component fails or is deleted, it is restored automatically.

**Role 2: Service composition engine**

Platform providers define services as Crossplane XRDs and compositions. Each composition is a pipeline of functions — primarily `function-kcl` — that translates a consumer's claim into the infrastructure resources needed to fulfil it. Crossplane manages the full lifecycle: create, update, reconcile drift, and delete in the correct order.

**Providers installed on SCO:**
- `provider-kubernetes` — manages Kubernetes resources on the service cluster (Crossplane's workhorse for almost everything)
- `provider-helm` — deploys Helm releases from compositions (used for api-syncagent deployments)
- `provider-kcp` — manages KCP workspace resources (APIExports, APIBindings, workspace hierarchy)
- `provider-keycloak` — manages Keycloak realms, users, groups, and clients
- `provider-aws` / `provider-azure` / `provider-gcp` — cloud infrastructure for compositions that require it
- `provider-vault` (OpenBao-compatible) — manages secrets and dynamic credentials

**Key functions:**
- `function-kcl` — the primary composition logic engine; runs KCL scripts to produce composed resources
- `function-auto-ready` — detects readiness from composed resource conditions automatically
- `function-environment-configs` — injects platform configuration into composition context

---

## Virtual API Layer

### KCP (Kubernetes Control Plane)

KCP provides the multi-tenant virtual API layer. It runs as a service within the management cluster and serves thousands of independent, isolated Kubernetes API endpoints (workspaces) from a single process.

**Role in SCO:**
- Provides each organisation with an organisation workspace
- Provides each project with a project workspace — its own Kubernetes API endpoint
- Hosts `APIExport` resources that declare which APIs are available to consumer workspaces
- Routes API requests from consumers to the api-syncagent for fulfillment
- Enforces API-level isolation: resources in one workspace are invisible to all other workspaces

**Workspace hierarchy:**
```
root (platform)
├── org-acme (organisation workspace)
│   ├── proj-frontend (project workspace)
│   └── proj-backend  (project workspace)
└── org-globex
    └── proj-apps
```

**Integration points:** KCP integrates with the api-syncagent (which bridges workspace API calls to the service cluster), Keycloak (for OIDC token validation per workspace), and MTO (which provisions the physical namespace layer backing each project).

See [Virtual API Layer](virtual-api-layer.md) and [KCP Integration](../integrations/kcp.md) for details.

### API Sync Agent

The api-syncagent is a per-API-group process that bridges KCP workspaces and the Crossplane service cluster.

**Role in SCO:**
- Watches consumer project workspaces for new claims of published resource types
- Creates corresponding objects on the service cluster in per-workspace namespaces
- Synchronises status and connection details from the service cluster back to the consumer workspace

One sync agent runs per published API group. It is deployed automatically when a platform provider creates an `ApiExport` claim.

See [Publishing APIs](../service-provider-guide/api-publishing/publishing-apis.md).

---

## Tenancy Enforcement

### Multi-Tenant Operator (MTO)

MTO enforces physical tenancy in the management cluster. While KCP provides API-level isolation, MTO ensures the underlying namespace, network, quota, and RBAC resources backing each project are properly isolated and continuously reconciled.

**Role in SCO:**
- Creates and maintains namespaces for each project (one namespace set per project)
- Applies `ResourceQuota` and `LimitRange` to enforce compute and storage limits
- Applies `NetworkPolicy` to prevent cross-project traffic at the infrastructure level
- Creates `RoleBinding` resources from Keycloak group membership to Kubernetes RBAC roles
- Applies namespace templates — standard tooling, default policies, monitoring configuration — to every project namespace

**Integration points:** MTO watches `Tenant` resources created by SCO's project controller. It integrates with Keycloak group membership for RBAC propagation and with KCP's workspace identity for namespace labelling.

See [MTO Integration](../integrations/mto.md).

---

## Identity

### Keycloak

Keycloak is the identity platform. Each organisation gets its own fully isolated realm with no shared user database, no cross-realm token validity, and independent authentication flows.

**Role in SCO:**
- Provides OIDC authentication for the SCO web console
- Issues tokens validated by KCP workspace API servers (per-organisation OIDC issuer)
- Manages users, groups, and role assignments per organisation
- Supports federation with corporate identity providers (LDAP, SAML, OIDC)
- Group membership in Keycloak is propagated by MTO into Kubernetes RBAC

**Integration points:** Keycloak integrates with KCP (as the OIDC provider per organisation workspace), with MTO (group membership → RBAC), and with the SCO IAM compositions (`iam.cloud.stakater.com/v1 User` and `Group`) that manage realm users and groups via Crossplane.

See [Keycloak Integration](../integrations/keycloak.md).

---

## Secrets Management

### OpenBao

OpenBao is the open-source secrets management platform (community fork of HashiCorp Vault). It runs within the management cluster and provides dynamic secrets, PKI infrastructure, and key-value secret storage for both platform components and consumer workloads.

**Role in SCO:**
- Issues dynamic credentials for platform services (database passwords, cloud provider keys) that expire automatically and are rotated without manual intervention
- Provides a PKI engine for TLS certificate issuance used by platform components and hosted clusters
- Stores platform secrets (Keycloak admin credentials, KCP bootstrap tokens) in encrypted, auditable storage
- Consumer workloads can request secrets from OpenBao through the External Secrets Operator or the OpenBao agent sidecar, scoped to their project's policy

**Integration points:** Crossplane's Vault-compatible provider creates and manages OpenBao policies, mounts, and roles as part of platform compositions. Consumer access to secrets is gated through OpenBao policies generated per organisation and project.

---

## Infrastructure Services

### OpenShift Virtualization (KubeVirt)

OpenShift Virtualization extends OpenShift with the ability to run virtual machines alongside containers on the same cluster, using KVM hardware virtualisation on bare-metal nodes.

**Role in SCO:**
- Powers the `VirtualMachine` service — SCO's built-in VM-as-a-service offering
- VMs are Kubernetes objects (`VirtualMachine`, `VirtualMachineInstance`, `DataVolume`) managed like any other workload
- Provides live migration, snapshots, and cloning capabilities
- Integrates with Kubernetes networking (Multus, OVN) and storage (CDI, ODF)

**Service delivered to consumers:** A consumer applies a `compute.cloud.stakater.com/v1 VirtualMachine` claim. The composition provisions a KubeVirt `VirtualMachine` with the chosen OS image, instance type, SSH key, and network configuration. The consumer receives an IP address or hostname to connect to their VM.

**Supported instance families:**

| Family | Character |
|--------|-----------|
| `o1` | General-purpose balanced compute |
| `cx1` | Compute-optimised |
| `m1` | Memory-optimised |
| `n1` | Network-optimised |
| `rt1` | Real-time workloads |
| `u1` | Ultra high-memory |

### HyperShift

HyperShift is Red Hat's hosted control plane technology. It runs OpenShift cluster control planes as pods on the management cluster, separating the control plane from the data plane (worker nodes).

**Role in SCO:**
- Powers the `OpenShiftCluster` service — SCO's Kubernetes-as-a-service offering
- Control planes for hosted clusters run in the management cluster's `hypershift` namespace set
- Worker node pools are provisioned on available infrastructure (bare metal, cloud VMs)
- Dramatically reduces resource overhead vs. standalone clusters — no dedicated control plane nodes required per tenant cluster
- Enables fast cluster provisioning (minutes) and simplified upgrades

**Service delivered to consumers:** A consumer applies a `kubernetes.cloud.stakater.com/v1 OpenShiftCluster` claim. HyperShift provisions a complete OpenShift cluster: an etcd instance, API server, controller manager, scheduler, and an ingress and DNS configuration — all running as pods. The consumer receives a kubeconfig for cluster-admin access to their hosted cluster.

---

## Operator Ecosystem: Services to Publish

SCO's composition engine can wrap any Kubernetes operator. The following are well-tested, Red Hat-supported operators that platform providers can publish as self-service catalogue entries on top of SCO:

### Strimzi (Apache Kafka)

Strimzi manages Apache Kafka clusters, topics, users, and connectors as Kubernetes CRDs. On SCO, a provider can expose a `KafkaCluster` claim backed by a Strimzi composition — the consumer declares a managed Kafka cluster and Strimzi reconciles the underlying brokers, ZooKeeper (or KRaft) nodes, and storage.

**Use cases:** Event streaming pipelines, microservice decoupling, real-time data processing.

### CloudNativePG (PostgreSQL)

CloudNativePG manages PostgreSQL clusters with high availability, streaming replication, automated failover, and continuous archiving to object storage. A `PostgreSQLDatabase` service on SCO wraps CNPG to give consumers on-demand, production-grade PostgreSQL with connection pooling (PgBouncer) and backup configured automatically.

**Use cases:** Application databases, analytics backends, multi-tenant SaaS storage.

### Red Hat OpenShift AI (RHOAI)

OpenShift AI provides a data science and machine learning platform — Jupyter notebooks, model serving (OpenVINO, vLLM, Triton), model registries, and data pipelines. On SCO, a provider can offer a `DataScienceProject` service that provisions a fully configured ML environment for a team, isolated within their project.

**Use cases:** AI/ML development environments, model training, inference serving.

### cert-manager

cert-manager automates TLS certificate issuance and renewal from ACME (Let's Encrypt), internal PKI, or OpenBao/Vault. SCO uses cert-manager internally for platform certificate management. Providers can also expose certificate management as a self-service capability within consumer projects.

**Use cases:** Application TLS, internal PKI, mutual TLS for service meshes.

### OpenShift Service Mesh (Istio)

OpenShift Service Mesh provides traffic management, mutual TLS, observability, and policy enforcement for microservices. Providers can offer a `ServiceMesh` service that provisions an isolated control plane for a consumer's project.

**Use cases:** Microservice observability, mTLS enforcement, canary deployments, traffic shaping.

### Redis (via Redis Operator)

A managed Redis instance or cluster for caching and session storage. The Redis operator provides high-availability Redis with sentinel or cluster mode, exposed via a simple claim.

**Use cases:** Application caching, session storage, rate limiting, pub/sub.

### Elasticsearch / OpenSearch

Full-text search and log aggregation platforms. Providers can expose cluster provisioning as a service, with the operator managing index lifecycle, snapshots, and security configuration.

**Use cases:** Application search, log aggregation, observability data.

---

## Component Interaction Summary

```
                     ┌──────────┐
                     │  GitOps  │◄── Git repository (desired state)
                     │ (ArgoCD) │
                     └────┬─────┘
                          │ installs and maintains
                          ▼
┌─────────────────────────────────────────────────────┐
│                    Crossplane                        │
│   ┌──────────────┐     ┌──────────────────────────┐ │
│   │   Platform   │     │   Service compositions   │ │
│   │compositions  │     │  (provider-defined)      │ │
│   └──────┬───────┘     └─────────────┬────────────┘ │
└──────────┼──────────────────────────┼───────────────┘
           │ provisions               │ produces
           ▼                          ▼
  ┌────────────────┐        ┌──────────────────────┐
  │  KCP · MTO     │        │  KubeVirt · HyperShift│
  │  Keycloak      │        │  OpenBao · Operators  │
  │  OpenBao       │        │  (infrastructure)     │
  └────────┬───────┘        └──────────────────────┘
           │                          ▲
           │ virtual API              │ physical resources
           ▼                          │
  ┌────────────────────┐    ┌─────────┴────────────┐
  │   KCP Workspace    │◄───│    api-syncagent      │
  │  (per project)     │    │  (bridges workspaces) │
  └────────────────────┘    └──────────────────────┘
           ▲
           │ kubectl / GitOps / Terraform
  ┌────────┴────────┐
  │    Consumer     │
  └─────────────────┘
```

---

## What's Next?

- [Architecture](architecture.md) — Layered overview and design principles
- [Virtual API Layer](virtual-api-layer.md) — How KCP workspaces and API routing work
- [Crossplane Integration](../integrations/crossplane.md) — Writing compositions and managing providers
- [MTO Integration](../integrations/mto.md) — Tenancy enforcement reference
- [Keycloak Integration](../integrations/keycloak.md) — Identity management reference
