# API Reference

Complete reference documentation for Stakater Cloud Orchestrator APIs.

## API Groups

SCO APIs are split into two groups based on intended audience.

### Public APIs (`*.cloud.stakater.com`)

User-facing APIs designed for cloud users — developers, team leads, and organisation administrators. These are the APIs you interact with day-to-day to manage your projects, identities, clusters, and virtual machines.

| API | Group | Kind | Description |
|-----|-------|------|-------------|
| [Project](public-apis/project.md) | `tenant.cloud.stakater.com/v1` | `Project` | Isolated project with network, quota, and access control |
| [IAM User](public-apis/iam-user.md) | `iam.cloud.stakater.com/v1` | `User` | Organisation user identity |
| [IAM Group](public-apis/iam-group.md) | `iam.cloud.stakater.com/v1` | `Group` | Organisation group with optional membership management |
| [OpenShift Cluster](public-apis/openshift-cluster.md) | `kubernetes.cloud.stakater.com/v1` | `OpenShiftCluster` | Managed OpenShift hosted cluster |
| [Virtual Machine](public-apis/virtual-machine.md) | `compute.cloud.stakater.com/v1` | `VirtualMachine` | Virtual machine with predefined flavours and instance types |

### Private APIs (`infrastructure.stakater.com`)

Low-level infrastructure APIs used internally by the SCO platform. These are documented here for platform engineers and operators.

| API | Group | Kind | Description |
|-----|-------|------|-------------|
| [HyperShift Hosted Cluster](private-apis/hypershift-hosted-cluster.md) | `infrastructure.stakater.com/v1` | `HyperShiftHostedCluster` | HyperShift hosted cluster with full etcd backup and provider config |
| [Virtual Machine (Infrastructure)](private-apis/virtual-machine-infrastructure.md) | `infrastructure.stakater.com/v1` | `VirtualMachine` | Full-control VM with explicit CPU, memory, storage, and network config |

## Reading the API Docs

Each API page includes:

- **Overview** — API group, version, kind, and scope
- **Spec Parameters** — all available fields with types, defaults, and descriptions
- **Status Fields** — fields available in `.status` after the resource is reconciled
- **Example** — minimal and full YAML examples
