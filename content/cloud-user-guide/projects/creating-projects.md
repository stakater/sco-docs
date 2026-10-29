# Creating Projects

Projects are isolated environments where you provision and manage services. Each project has its own Kubernetes API endpoint, its own network isolation, and its own resource quota. Projects are created by organisation administrators.

For the full parameter reference, see the [Create Project](../../how-to-guides/user/create-project.md) how-to guide.

---

## Who Creates Projects

Projects are created by **organisation administrators**. Once created, a project is assigned to specific users or groups who can then provision services within it.

If you need a project and do not have admin access, contact your organisation administrator.

---

## Creating a Project

Apply a `tenant.cloud.stakater.com/v1 Project` claim against your organisation's API endpoint:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: frontend-dev
spec:
  parameters:
    name: frontend-dev
    network:
      name: frontend-network
      cidr: 10.200.0.0/16
    tenantQuota: small
    access:
      - role: platform-services-admin
        users:
          - alice@acmecorp.example.com
      - role: compute-user
        groups:
          - frontend-team
```

List individual users by their **email address**, the same address they log in with. Groups are listed by group name. See [Project Roles](#project-roles) for the roles you can use.

```bash
kubectl apply -f frontend-dev-project.yaml
```

Check that the project is ready:

```bash
kubectl get project frontend-dev
```

```text
NAME           STATUS   AGE
frontend-dev   Ready    45s
```

---

## Project Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `name` | Yes | Project display name |
| `network.name` | Yes | Network identifier for the project |
| `network.cidr` | Yes | IP range for the project network |
| `tenantQuota` | No | Quota profile: `small`, `medium`, or `large` (default: `small`) |
| `access` | No | Users (by email address) and groups with access, and their roles. See [Project Roles](#project-roles) |

---

## Project Roles

Each `access` entry grants one role to a list of users and groups. The platform creates these roles in every project:

| Role | What it grants |
|------|----------------|
| `platform-services-admin` | Full control of every platform service in the project: create, change and delete virtual machines, clusters, databases, buckets and so on, and start, stop, restart and open the console of virtual machines. Can also read the project's Secrets |
| `platform-services-view` | Read-only access to every platform service in the project, including virtual machine consoles and metrics. Can also read the project's Secrets |
| `<service>-user` | Full control of one platform service. Can also read the project's Secrets, which hold service connection credentials |
| `<service>-viewer` | Read-only access to one platform service. Cannot read Secrets |

`<service>` is one of the platform services available in your project:

| Service | Resources it covers |
|---------|---------------------|
| `compute` | Virtual machines, their volumes, snapshots and backups |
| `database` | Databases such as `Postgres` |
| `kubernetes` | OpenShift clusters and node pools |
| `mesh` | Mesh routers, routes, groups and policies |
| `network` | Your organisation mesh |
| `secrets` | `Vault` |
| `storage` | S3 buckets |

For example, `compute-user` lets someone manage virtual machines only, and `database-viewer` lets someone see databases but not change them. Only services enabled on your platform have roles; if a service is not available in your project, its `-user` and `-viewer` roles do not exist.

!!! warning
    Use only the role names listed above. The platform accepts any role name without an error, and the project still reports `Ready`. A name that is not in this list does not grant an SCO role. If it matches a built-in Kubernetes role, such as `edit` or `cluster-admin`, the users get that built-in role inside the project, with far broader rights than any SCO role (for example creating and deleting Secrets, issuing service account tokens, or changing role-based access). If it matches nothing, they get no access at all. Check every `access` entry against this list before you apply it.

<!-- TODO(SA-8708): link SA-9299 / SA-9303 fixes here once role names are validated, and drop the warning if other names are rejected -->

---

## Quota Profiles

| Profile | CPU request | Memory | CPU limit | Storage |
|---------|-------------|--------|-----------|---------|
| `small` | 4 cores | 8 Gi | 8 cores | Limited |
| `medium` | 8 cores | 16 Gi | 16 cores | Moderate |
| `large` | 16 cores | 32 Gi | 32 cores | Large |

Contact your platform provider if none of the standard profiles fit your workload requirements.

---

## Getting the Project kubeconfig

Once your project is ready, get its kubeconfig to access it from the command line:

1. Open your project in the console
1. Switch the page from **Standard** to **Advanced**
1. In the **Access Configuration** section, open the kubeconfig and choose **Decoded**
1. Copy the YAML into `~/.kube/<project-name>.yaml`

Do not save the **Encoded** view: it is a single line of base64 text that `kubectl` cannot read. See [kubeconfig Generation](../kubectl-access/kubeconfig-generation.md) for details and for how organisation administrators can get it with `kubectl`.

```bash
export KUBECONFIG=~/.kube/frontend-dev.yaml
kubectl get virtualmachines
```

The downloaded kubeconfig has a single context, named `dev`.

---

## Deleting a Project

Projects are protected from deletion by default. If you delete a project while the protection is on, the project disappears from the console and from `kubectl get projects`, but **everything inside it keeps running**: virtual machines, clusters, networks and mesh access are left behind, and you can no longer see or remove them yourself. They keep consuming resources and stay reachable over the mesh.

To delete a project and everything in it:

1. Delete the virtual machines, clusters and other services in the project first, using the project kubeconfig:

    ```bash
    export KUBECONFIG=~/.kube/frontend-dev.yaml
    kubectl get virtualmachines,openshiftclusters
    kubectl delete virtualmachine <name>
    ```

1. With your organisation kubeconfig, turn off the deletion protection on the project:

    ```bash
    kubectl label project frontend-dev sco/deletion-protection=disabled
    ```

1. Wait about a minute for the change to reach all the project's resources.
1. Delete the project:

    ```bash
    kubectl delete project frontend-dev
    ```

!!! warning
    Never delete a project without the `sco/deletion-protection=disabled` label unless you intend to keep its resources running. If that has already happened, contact your platform provider to clean up what was left behind.

<!-- TODO(SA-8708): add how to confirm the deletion completed, once the stuck-deletion issue seen in ST-15 (#44) is resolved -->

---

## What's Next?

- [Project Structure](project-structure.md) — What's inside a project
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure CLI access to your project
- [Browsing Marketplace](../solutions/browsing-marketplace.md) — Find services to provision
- [Create Project How-To](../../how-to-guides/user/create-project.md) — Full parameter reference
