# Creating Projects

Projects are isolated environments where you provision and manage services. Each project has its own Kubernetes API endpoint, its own network isolation, and its own resource quota. Projects are created by organisation administrators.

For the full parameter reference, see the [Create Project](../../how-to-guides/user/create-project.md) how-to guide.

---

## Who Creates Projects

Projects are created by **organisation administrators** — users with the `admin` role at the organisation level. Once created, a project is assigned to specific users or groups who can then provision services within it.

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
      - role: admin
        users:
          - alice@acmecorp.example.com
      - role: edit
        groups:
          - frontend-team
```

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
| `access` | No | Users and groups with access, and their roles |

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

Once your project is ready, download the kubeconfig to access it from the command line:

1. Navigate to your project in the console
1. Click **Settings** or **Access**
1. Click **Download kubeconfig**

Or request it from your platform administrator. Save it to `~/.kube/<project-name>.yaml` and set:

```bash
export KUBECONFIG=~/.kube/frontend-dev.yaml
kubectl get virtualmachines
```

---

## What's Next?

- [Project Structure](project-structure.md) — What's inside a project
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure CLI access to your project
- [Browsing Marketplace](../solutions/browsing-marketplace.md) — Find services to provision
- [Create Project How-To](../../how-to-guides/user/create-project.md) — Full parameter reference
