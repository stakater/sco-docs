# Kubernetes Provider

Advanced Terraform Kubernetes provider patterns for managing SCO project resources.

---

## Multiple Projects

Use provider aliases to manage resources across multiple projects in the same Terraform configuration:

```hcl
provider "kubernetes" {
  alias          = "frontend"
  config_path    = "~/.kube/proj-frontend.yaml"
  config_context = "proj-frontend"
}

provider "kubernetes" {
  alias          = "backend"
  config_path    = "~/.kube/proj-backend.yaml"
  config_context = "proj-backend"
}

resource "kubernetes_manifest" "frontend_vm" {
  provider = kubernetes.frontend
  manifest = { ... }
}

resource "kubernetes_manifest" "backend_db" {
  provider = kubernetes.backend
  manifest = { ... }
}
```

---

## Managing All SCO Services

### Virtual Machine

```hcl
resource "kubernetes_manifest" "app_vm" {
  manifest = {
    apiVersion = "compute.cloud.stakater.com/v1"
    kind       = "VirtualMachine"
    metadata   = { name = "app-vm" }
    spec = {
      parameters = {
        flavour      = "rhel9"
        instanceType = "o1.large"
        storageSize  = "medium"
        connection   = "public"
        sshPublicKey = var.ssh_public_key
      }
    }
  }
  timeouts { create = "10m"; delete = "10m" }
}
```

### OpenShift Cluster

```hcl
resource "kubernetes_manifest" "dev_cluster" {
  manifest = {
    apiVersion = "kubernetes.cloud.stakater.com/v1"
    kind       = "OpenShiftCluster"
    metadata   = { name = "dev-cluster", namespace = "my-tenant" }
    spec = {
      parameters = {
        clusterName     = "dev-cluster"
        version         = "4.19"
        defaultNodepool = { size = "large", replicas = 3 }
        networking      = { mode = "public" }
      }
    }
  }
  timeouts { create = "30m"; delete = "20m" }
}
```

### IAM Resources

```hcl
resource "kubernetes_manifest" "user_alice" {
  manifest = {
    apiVersion = "iam.cloud.stakater.com/v1"
    kind       = "User"
    metadata   = { name = "alice" }
    spec = {
      parameters = {
        username      = "alice"
        email         = "alice@example.com"
        firstName     = "Alice"
        lastName      = "Smith"
        emailVerified = true
        enabled       = true
      }
    }
  }
}
```

---

## State Management

Import existing SCO claims into Terraform state:

```bash
terraform import kubernetes_manifest.app_vm \
  "apiVersion=compute.cloud.stakater.com/v1,kind=VirtualMachine,name=app-vm"
```

Use remote state for team environments to avoid state conflicts:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "sco/proj-frontend/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

---

## What's Next?

- [Setup Terraform](setup-terraform.md) — Initial provider setup
- [GitOps Access](../gitops-access/argocd-setup.md) — Continuous deployment with ArgoCD or Flux
- [API Reference](../../api-reference/overview.md) — Full parameter reference for all services
