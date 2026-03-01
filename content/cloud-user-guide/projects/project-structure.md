# Project Structure

A project is a fully isolated Kubernetes environment. From your perspective as a consumer, a project behaves like a dedicated cluster — with its own API endpoint, its own resources, and its own access controls.

---

## What a Project Gives You

| Capability | Description |
|------------|-------------|
| **Kubernetes API endpoint** | A unique kubeconfig URL to use with `kubectl`, Terraform, ArgoCD, or Flux |
| **Service catalogue** | All services published by your platform team, available as native Kubernetes resource types |
| **Network isolation** | Your project's network traffic is isolated from all other projects |
| **Resource quota** | CPU, memory, and storage limits set by your organisation administrator |
| **RBAC** | Users and groups you've been granted access to; no cross-project visibility |

---

## The API Endpoint

Every project has its own Kubernetes API endpoint. This is the URL in your project's kubeconfig:

```
https://kcp.example.com/clusters/org-acme:frontend-dev
```

All standard Kubernetes tools work against this endpoint. There is nothing special to configure — use the kubeconfig your administrator provides.

---

## Available Resource Types

Within your project, you can list the resource types available to you:

```bash
kubectl api-resources
```

This shows all service types your platform team has published — for example:

```text
NAME                   SHORTNAMES   APIVERSION                          KIND
virtualmachines                     compute.cloud.stakater.com/v1       VirtualMachine
openshiftclusters                   kubernetes.cloud.stakater.com/v1    OpenShiftCluster
postgresqldatabases                 databases.cloud.stakater.com/v1     PostgreSQLDatabase
users                               iam.cloud.stakater.com/v1           User
groups                              iam.cloud.stakater.com/v1           Group
```

The exact list depends on what your platform team has published.

---

## Network Isolation

Your project's network is isolated from all other projects by default. Services running in your project cannot be reached from other projects, and vice versa. This isolation is enforced at the infrastructure level, not just by policy.

Your project can reach external networks and the internet depending on your platform's egress configuration — contact your administrator if you need specific network access.

---

## Resource Quota

Every project has compute and storage limits set by your administrator. If you exceed your quota, resource creation will fail with a quota error. Check your current usage and limits:

```bash
kubectl describe resourcequota
```

Contact your organisation administrator to request a quota increase.

---

## Project Isolation

Everything you create in your project stays in your project:

- Other teams cannot see your `VirtualMachine`, `OpenShiftCluster`, or other resources
- You cannot see resources in other teams' projects
- Your credentials (kubeconfig, tokens) cannot be used to access any other project

---

## What's Next?

- [Browsing Marketplace](../solutions/browsing-marketplace.md) — Find services to provision in your project
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure kubectl with your project kubeconfig
- [Project Architecture](../../service-provider-guide/projects/project-architecture.md) — Technical deep dive on project internals
