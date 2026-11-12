# ArgoCD Setup

ArgoCD can deploy SCO claims from Git, because SCO claims are ordinary Kubernetes YAML. Connecting ArgoCD to an SCO project, however, needs an **automation identity**, and that is not available to project users yet.

!!! note
    Until the automation identity is available, use [Terraform](../terraform-access/setup-terraform.md) with your own project login to manage project resources programmatically.

---

## Why ArgoCD Cannot Connect Yet

ArgoCD needs long-lived credentials for every cluster it deploys to. Your project kubeconfig does not provide them:

- **`argocd cluster add` fails.** It tries to create a service account, a cluster role and a role binding in the target, and to read a token for it. Project users, including organisation administrators, are not allowed to create any of these, so the command stops with `failed to create service account "argocd-manager" ... access denied`.
- **Your kubeconfig signs in as you, through a browser.** It opens a browser login and caches a short-lived token. An ArgoCD server has no browser, and copying your personal login into ArgoCD would give it your access.

A dedicated automation identity, scoped to your organisation or a project, is planned for tools such as ArgoCD, Flux and CI pipelines. This page will describe how to connect ArgoCD once it is available.

<!-- TODO(SA-8708): once the automation identity (TechnicalUser, iam.cloud.stakater.com/v1) is available to project users, document connecting ArgoCD with a declarative cluster Secret that uses its credentials. -->

---

## Preparing Your Git Repository

You can already keep your SCO claims in Git. They look the same as any other Kubernetes YAML, and the same files work with `kubectl apply` today:

```yaml
# environments/frontend/virtual-machine.yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: app-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.large
    connection: private
    sshPublicKey:
      data: <base64-encoded OpenSSH public key>
```

`sshPublicKey.data` is the OpenSSH public key, base64-encoded on a single line.

---

## What's Next?

- [Setup Terraform](../terraform-access/setup-terraform.md) — The supported programmatic path today
- [Flux Setup](flux-setup.md) — Flux has the same limitation
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — kubectl access to your project
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — Understanding SCO claim structure
