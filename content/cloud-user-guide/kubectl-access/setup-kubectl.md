# Setup kubectl

`kubectl` works against your project's virtual API endpoint exactly as it would against any Kubernetes cluster. You need a kubeconfig file and a working `kubectl` installation.

---

## Prerequisites

- `kubectl` installed ([official installation guide](https://kubernetes.io/docs/tasks/tools/))
- Access to a project (granted by your organisation administrator)
- Your project kubeconfig (downloaded from the console or provided by your administrator)

---

## Step 1: Install kubectl

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Windows
choco install kubernetes-cli
```

Verify:

```bash
kubectl version --client
```

---

## Step 2: Download Your Project kubeconfig

1. Log in to the SCO console
1. Navigate to your project
1. Click **Settings** or **Access**
1. Click **Download kubeconfig**

Save the file, for example as `~/.kube/my-project.yaml`.

---

## Step 3: Use the kubeconfig

### Option A: Environment variable

```bash
export KUBECONFIG=~/.kube/my-project.yaml
kubectl get virtualmachines
```

### Option B: Merge into existing config

```bash
KUBECONFIG=~/.kube/config:~/.kube/my-project.yaml kubectl config view --flatten > ~/.kube/merged.yaml
mv ~/.kube/merged.yaml ~/.kube/config
kubectl config use-context my-project
```

### Option C: Per-command flag

```bash
kubectl --kubeconfig ~/.kube/my-project.yaml get virtualmachines
```

---

## Step 4: Verify Access

```bash
kubectl cluster-info
kubectl api-resources | grep cloud.stakater.com
kubectl get virtualmachines
```

---

## Working with Multiple Projects

Keep separate kubeconfig files per project and switch with the `KUBECONFIG` environment variable, or merge them and use context switching:

```bash
kubectl config get-contexts
kubectl config use-context proj-backend
```

---

## Authentication

Your project kubeconfig uses OIDC authentication. When the token expires, `kubectl` prompts you to re-authenticate via your organisation's login page. Install the `oidc-login` plugin to handle this automatically:

```bash
kubectl krew install oidc-login
```

---

## What's Next?

- [kubeconfig Generation](kubeconfig-generation.md) — Understanding your kubeconfig structure
- [Browsing Marketplace](../solutions/browsing-marketplace.md) — Discover available services
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — Apply claims with kubectl
