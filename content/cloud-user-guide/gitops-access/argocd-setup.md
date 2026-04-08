# Argo CD Setup

You can use Argo CD to continuously deploy and manage resources in your SCO project workspace. Argo CD treats your project's virtual API endpoint as a standard Kubernetes cluster.

---

## How it Works

Your project exposes a standard Kubernetes API endpoint through a kubeconfig. Argo CD registers this endpoint as a target cluster and syncs your Git repository's manifests, including SCO claims, into the project workspace.

SCO claim manifests in your Git repository look the same as any other Kubernetes YAML. Argo CD does not need special configuration to handle them.

---

## Prerequisites

- Argo CD deployed (within your project workspace or externally)
- Your project kubeconfig (see [Setup kubectl](../kubectl-access/setup-kubectl.md))
- A Git repository containing your manifests

---

## Step 1: Register Your Project as a Cluster

From the Argo CD CLI, add your project's API endpoint as a target cluster using your kubeconfig:

```bash
# Set the project kubeconfig as active
export KUBECONFIG=~/.kube/my-project.yaml

# Add the cluster to Argo CD
argocd cluster add my-project --name sco-proj-frontend
```

Argo CD will create a service account in your project workspace and use it for ongoing API access.

Verify the cluster was added:

```bash
argocd cluster list
```

---

## Step 2: Create an Argo CD Application

Define an Argo CD `Application` that points at your Git repository and targets your SCO project:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-infra
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: environments/frontend
  destination:
    server: https://kcp.example.com/clusters/org-acme:proj-frontend
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

The `destination.server` is your project's API endpoint URL from the kubeconfig.

Apply this Application to your Argo CD instance:

```bash
kubectl apply -f application.yaml -n argocd
```

---

## Step 3: Add SCO Claims to Your Git Repository

In the Git path Argo CD is watching, add your SCO claim manifests:

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
    sshPublicKey: "ssh-rsa AAAAB3..."
```

When you push this to the repository, ArgoCD syncs it to your project workspace and the platform provisions the VM automatically.

---

## Automation Identity (Coming Soon)

Currently, ArgoCD cluster registration uses the credentials embedded in your project kubeconfig. A dedicated **automation identity** capability is planned that will allow you to create a long-lived service account claim scoped to your organisation, specifically for use by automation tools like ArgoCD, Flux, and Terraform — without relying on a personal user kubeconfig.

---

## What's Next?

- [Flux Setup](flux-setup.md) — Alternative GitOps with Flux
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — kubectl access to your project
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — Understanding SCO claim structure
