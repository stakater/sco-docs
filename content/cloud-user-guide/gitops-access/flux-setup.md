# Flux Setup

Flux can continuously reconcile your SCO project workspace with a Git repository. Since your project exposes a standard Kubernetes API endpoint, Flux works against it without modification.

---

## Prerequisites

- `flux` CLI installed ([official installation guide](https://fluxcd.io/flux/installation/))
- Your project kubeconfig (see [Setup kubectl](../kubectl-access/setup-kubectl.md))
- A Git repository containing your manifests

---

## Step 1: Bootstrap Flux

Bootstrap Flux into your project workspace:

```bash
export KUBECONFIG=~/.kube/my-project.yaml

flux bootstrap git \
  --url=ssh://git@github.com/your-org/your-repo.git \
  --branch=main \
  --path=clusters/proj-frontend
```

Flux creates the `flux-system` namespace in your project workspace, and installs its controllers.

---

## Step 2: Add SCO Claims to Git

In the Git path Flux is watching, add SCO claim manifests:

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
    sshPublicKey: "ssh-rsa AAAAB3..."
```

Commit and push. Flux applies the manifest to your project workspace within the configured sync interval.

---

## Step 3: Monitor

```bash
flux get all
kubectl get virtualmachines
flux logs
```

---

## Targeting Your Project from an External Flux Instance

If Flux is already running elsewhere and you want it to deploy into your SCO project, create a `Secret` with your kubeconfig and reference it in a `Kustomization`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sco-project-kubeconfig
  namespace: flux-system
type: Opaque
stringData:
  value: |
    # paste project kubeconfig contents here
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: sco-proj-frontend
  namespace: flux-system
spec:
  interval: 5m
  path: ./environments/proj-frontend
  prune: true
  sourceRef:
    kind: GitRepository
    name: your-repo
  kubeConfig:
    secretRef:
      name: sco-project-kubeconfig
```

---

## Automation Identity (Coming Soon)

Currently, Flux uses the credentials in your project kubeconfig. A dedicated **automation identity** claim type is planned — allowing you to create a long-lived, scoped service account for CI/CD tools without relying on a personal kubeconfig.

---

## What's Next?

- [ArgoCD Setup](argocd-setup.md) — Alternative GitOps with ArgoCD
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — kubectl access to your project
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — SCO claim structure
