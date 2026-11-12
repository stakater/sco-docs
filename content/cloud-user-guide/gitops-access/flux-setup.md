# Flux Setup

Flux can reconcile SCO claims from Git, because SCO claims are ordinary Kubernetes YAML. Connecting Flux to an SCO project, however, needs an **automation identity**, and that is not available to project users yet.

!!! note
    Until the automation identity is available, use [Terraform](../terraform-access/setup-terraform.md) with your own project login to manage project resources programmatically.

---

## Why Flux Cannot Connect Yet

- **`flux bootstrap` cannot run against a project.** Bootstrap installs the Flux controllers, their API definitions, a `flux-system` namespace and cluster-wide role bindings into the target. Project users are not allowed to create these, and a project runs only the services you provision through claims, not arbitrary controllers.
- **An external Flux instance cannot use your project kubeconfig.** A Flux `Kustomization` can deploy to a remote API through a kubeconfig stored in a `Secret`, but your project kubeconfig signs in as you through a browser login with a short-lived token. A Flux controller has no browser, and storing your personal login in a `Secret` would give Flux your access.

A dedicated automation identity, scoped to your organisation or a project, is planned for tools such as Flux, ArgoCD and CI pipelines. This page will describe how to connect Flux once it is available.

<!-- TODO(SA-8708): once the automation identity (TechnicalUser, iam.cloud.stakater.com/v1) is available to project users, document an external Flux Kustomization with spec.kubeConfig.secretRef pointing at its kubeconfig. -->

---

## Preparing Your Git Repository

You can already keep your SCO claims in Git. They look the same as any other Kubernetes YAML, and the same files work with `kubectl apply` today:

```yaml
# clusters/proj-frontend/virtual-machine.yaml
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
- [ArgoCD Setup](argocd-setup.md) — ArgoCD has the same limitation
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — kubectl access to your project
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — SCO claim structure
