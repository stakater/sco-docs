# Solution Catalog

Reference for all service types available in the SCO marketplace — built-in services and common custom solutions that platform teams typically add.

---

## Built-in Services

These services are available on every SCO installation.

### Virtual Machine

**API:** `compute.cloud.stakater.com/v1 VirtualMachine`

Linux virtual machines running on OpenShift Virtualization (KubeVirt).

| Parameter | Required | Description |
|-----------|----------|-------------|
| `flavour` | Yes | OS image: `rhel7`, `rhel8`, `rhel9`, `rhel10`, `fedora`, `centos-stream9`, `centos-stream10` |
| `instanceType` | Yes | Size: `o1.small`, `o1.medium`, `o1.large`, `cx1.medium`, `m1.large`, etc. |
| `storageSize` | No | Disk: `small` (20 Gi), `medium` (50 Gi), `large` (100 Gi), `xlarge` (200 Gi) |
| `connection` | No | `private` (cluster-internal) or `public` (LoadBalancer IP) |
| `sshPublicKey.data` | No | SSH public key |
| `cloudInit.userData` | No | Cloud-init configuration |

Instance type families: `o1` (general), `cx1` (compute), `m1` (memory), `n1` (network), `rt1` (real-time), `u1` (ultra high-memory)

Full reference: [Virtual Machine API](../api-reference/public-apis/virtual-machine.md)

---

### OpenShift Cluster

**API:** `kubernetes.cloud.stakater.com/v1 OpenShiftCluster`

Hosted OpenShift clusters with cluster-admin access.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `clusterName` | Yes | Cluster name |
| `compute.cpu` | Yes | CPU per worker node |
| `compute.memory` | Yes | Memory per worker node |
| `version` | No | OpenShift version: `4.18`, `4.19`, `4.20` (default: `4.19`) |
| `nodePool.replicas` | No | Worker node count (default: 2) |
| `storage.rootVolumeSize` | No | Root disk size in Gi |

Full reference: [OpenShift Cluster API](../api-reference/public-apis/openshift-cluster.md)

---

### IAM User

**API:** `iam.cloud.stakater.com/v1 User`

User accounts within your organisation's identity realm.

Full reference: [IAM User API](../api-reference/public-apis/iam-user.md)

---

### IAM Group

**API:** `iam.cloud.stakater.com/v1 Group`

Groups for organising users and managing project access.

Full reference: [IAM Group API](../api-reference/public-apis/iam-group.md)

---

## Common Custom Services

These services are commonly added by platform teams. Availability depends on your installation.

### PostgreSQL Database

**Example API:** `databases.cloud.stakater.com/v1 PostgreSQLDatabase`

Managed PostgreSQL instances backed by CloudNativePG. Supports standalone (1 instance) or high-availability (3 instances) configuration with automated backup.

**Typical parameters:** `dbName`, `version` (14/15/16), `storageGb`, `instances`

Provider guide: [Create a PostgreSQL Solution](../how-to-guides/provider/create-postgresql-solution.md)

---

### Kafka Cluster

**Example API:** `messaging.cloud.stakater.com/v1 KafkaCluster`

Apache Kafka clusters backed by `Strimzi` with configurable broker count, storage, and topic retention.

---

### Redis

**Example API:** `caching.cloud.stakater.com/v1 RedisInstance`

Managed Redis for caching, session storage, and pub/sub. Standalone or Sentinel HA.

---

### AI/ML Workspace

**Example API:** `ai.cloud.stakater.com/v1 DataScienceProject`

AI/ML development environments backed by OpenShift AI (RHOAI), providing Jupyter notebooks, model serving, and data pipelines.

---

## What's Next?

- [Browsing the Marketplace](browsing.md) — Discover services with kubectl
- [Provisioning Solutions](../cloud-user-guide/solutions/provisioning-solutions.md) — Apply a claim
- [API Reference](../api-reference/overview.md) — Full technical parameter reference
