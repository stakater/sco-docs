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

List individual users by their **email address**, the same address they log in with, and groups by their **group name**, exactly as the group was created (for example `frontend-team`, not a display name). The platform rejects anything else when you apply the project. See [Project Roles](#project-roles) for the roles you can use.

!!! note
    Mesh and virtual machine access (SSH, RDP) is granted through **groups only**: to groups with the `compute-user`, `admin` or `cluster-admin` role. A person listed under `users` gets the project and its secrets, but not mesh or virtual machine access. To give someone that access, add them to a group and grant one of those roles to the group.

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
| `network.mode` | No | How the project is networked: `udn` (default), `native` or `external`. See [Network Modes](#network-modes) |
| `network.cidr` | With `udn` | IP range for the project network. Choose one that no other project in your organisation uses |
| `network.name` | No | Name of the project network, `udn` mode only (default: `default`) |
| `network.externalRef` | With `external` | Name of the external network assigned to your organisation |
| `tenantQuota` | No | Quota profile: `small`, `medium`, or `large` (default: `small`) |
| `access` | No | Users (by email address) and groups (by group name) with access, and their roles. See [Project Roles](#project-roles) |

---

## Network Modes

| Mode | In the console | What the project gets |
|------|----------------|-----------------------|
| `udn` (default) | Isolated network | Its own private network, addressed from `network.cidr` |
| `native` | Shared cluster network | The platform's shared network, isolated from other projects by network policies. Choose it for virtual machines that must be reachable from this project's OpenShift clusters |
| `external` | External network | An external network assigned to your organisation, named by `network.externalRef` |

The console offers only the modes your platform supports. `external` is offered only where organisations have external networks; ask your platform provider if you need one.

!!! note
    A project cannot change to or from `udn` after it is created. To move to or from `udn`, create a new project with the mode you need.

---

## Project Roles

Each `access` entry grants one role to a list of users and groups. In the console, **Role** is a select that describes each role. The platform creates these roles in every project, and they are the ones to use:

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

The console also offers four built-in roles, last and labelled *unrestricted*:

| Role | What it grants |
|------|----------------|
| `cluster-admin` | Unrestricted control of everything in the project, including Secrets and who has access |
| `admin` | Control of nearly everything in the project, including Secrets and who has access |
| `edit` | Create, change and delete most resources in the project, including Secrets |
| `view` | Read most resources in the project, excluding Secrets |

Each is broader than any platform role. Prefer the platform roles, and use a built-in role only when no platform role covers what someone needs.

!!! warning
    The platform accepts any role name without an error, and the project still reports `Ready`. A name that matches no role grants nothing. Check every `access` entry against the roles above before you apply it.

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
