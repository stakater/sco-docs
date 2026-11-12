# How to Create a Project

Learn how to create an isolated project in your organisation.

Alex, a platform user at ACME Corp, needs a dedicated environment to deploy applications and provision cloud services. A project provides network isolation, role-based access, and quota controls for your team's resources.

## Prerequisites

- Access to your organisation's SCO platform
- The `project.tenant.cloud.stakater.com` API available
- `kubectl` configured with your organisation project kubeconfig

## What Gets Created

When you create a Project claim, the platform provisions:

- An isolated **project environment** scoped to your team
- Configurable resource **quota** for the project
- **Network isolation** with your chosen CIDR block
- **Identity groups** for read-only and admin access
- **Role-based access control** within the project

## Step 1: Define Your Project Claim

Create a file named `project.yaml` with the following minimal configuration:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: my-project
spec:
  parameters:
    name: my-project
    network:
      name: app-network
      cidr: 10.0.0.0/16
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `parameters.name` | Project name used for resource naming |
| `parameters.network.name` | Network identifier for the project's isolated network |
| `parameters.network.cidr` | CIDR block for the project network (e.g., `10.0.0.0/16`) |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `parameters.tenantQuota` | `small` | Quota size for the project (`small`, `medium`, `large`) |
| `parameters.access` | — | Role-based access entries for users and groups |

## Step 2: Add Access Control (Optional)

To grant specific users and groups access to the project, add an `access` block:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: my-project
spec:
  parameters:
    name: my-project
    network:
      name: app-network
      cidr: 10.0.0.0/16
    tenantQuota: small
    access:
      - role: platform-services-admin
        groups:
          - platform-admins
        users:
          - alex@acmecorp.example.com
      - role: platform-services-view
        groups:
          - developers
```

Each entry in `access` specifies a `role` and lists `users` (by email) or `groups` to bind to that role within the project. Use only the roles listed in [Project Roles](../../cloud-user-guide/projects/creating-projects.md#project-roles); any other name is accepted without an error but can grant far broader rights than intended.

The same entries also grant access to the project's folder in your organisation's Vault: `platform-services-admin` and `secrets-user` can read and write it, `platform-services-view` and `secrets-viewer` can read it. The Vault roles to sign in with appear in `status.openbao.roles`; see [Vault: Project access](../../api-reference/public-apis/vault.md#project-access).

## Step 3: Apply the Claim

```bash
kubectl apply -f project.yaml
```

## Step 4: Verify the Project

Check that the project claim was created and is progressing:

```bash
kubectl get project my-project
```

Wait for the project to become ready:

```text
NAME         READY   SYNCED   AGE
my-project   True    True     2m
```

You can also describe the claim to inspect status conditions:

```bash
kubectl describe project my-project
```

## Full Example

The following example creates a project with multiple access roles:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: team-dev
spec:
  parameters:
    name: team-dev
    network:
      name: dev-network
      cidr: 10.100.0.0/16
    tenantQuota: medium
    access:
      - role: platform-services-admin
        groups:
          - platform-admins
        users:
          - alex@acmecorp.example.com
      - role: platform-services-view
        groups:
          - developers
          - qa-team
```

## What's Next?

- [Create an IAM User](create-iam-user.md) - Add users to your organisation
- [Create an IAM Group](create-iam-group.md) - Organise users into groups
- [Provision a Virtual Machine](provision-virtual-machine.md) - Deploy a VM within your project
- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Provision an OpenShift cluster
