# Kubernetes Provider

More Terraform patterns for managing SCO project resources with the `alekc/kubectl` provider. Start with [Setup Terraform](setup-terraform.md) if you have not configured the provider yet.

!!! note
    The `hashicorp/kubernetes` provider (`kubernetes_manifest`) does not work for project users. Use `kubectl_manifest` from `alekc/kubectl`, as in the examples below.

Every example sets `namespace = "default"`. Terraform needs it set explicitly, even though `kubectl` fills it in for you.

---

## Multiple Projects

Download a kubeconfig for each project, and use provider aliases to manage resources across them in the same configuration. Check each file's context name with `kubectl config get-contexts --kubeconfig <file>`; console downloads use `dev`.

```hcl
provider "kubectl" {
  alias            = "frontend"
  config_path      = pathexpand("~/.kube/proj-frontend.yaml")
  config_context   = "dev"
  load_config_file = true
}

provider "kubectl" {
  alias            = "backend"
  config_path      = pathexpand("~/.kube/proj-backend.yaml")
  config_context   = "dev"
  load_config_file = true
}

# local.frontend_vm and local.backend_db hold claims shaped like the examples below
resource "kubectl_manifest" "frontend_vm" {
  provider  = kubectl.frontend
  yaml_body = yamlencode(local.frontend_vm)
}

resource "kubectl_manifest" "backend_db" {
  provider  = kubectl.backend
  yaml_body = yamlencode(local.backend_db)
}
```

---

## Managing SCO Services

### Virtual Machine

```hcl
resource "kubectl_manifest" "app_vm" {
  yaml_body = yamlencode({
    apiVersion = "compute.cloud.stakater.com/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = "app-vm"
      namespace = "default"
    }
    spec = {
      parameters = {
        flavour      = "rhel9"
        instanceType = "o1.large"
        storageSize  = "medium"
        connection   = "public"
        sshPublicKey = {
          data = base64encode(var.ssh_public_key)
        }
      }
    }
  })

  wait_for_rollout = false
}
```

`sshPublicKey` is an object; `data` holds the base64-encoded OpenSSH public key.

### OpenShift Cluster

```hcl
resource "kubectl_manifest" "dev_cluster" {
  yaml_body = yamlencode({
    apiVersion = "kubernetes.cloud.stakater.com/v1"
    kind       = "OpenShiftCluster"
    metadata = {
      name      = "dev-cluster"
      namespace = "default"
    }
    spec = {
      parameters = {
        version = "4.19"
        defaultNodepool = {
          size     = "large"
          replicas = 3
        }
        networking = {
          mode = "public"
        }
      }
    }
  })

  wait_for_rollout = false
}
```

The cluster name defaults to the claim name (`metadata.name`).

### IAM Resources

Organisation users are created by an organisation administrator (see [How to Create an IAM User](../../how-to-guides/user/create-iam-user.md)). Use a provider configured with that kubeconfig:

```hcl
resource "kubectl_manifest" "user_alice" {
  yaml_body = yamlencode({
    apiVersion = "iam.cloud.stakater.com/v1"
    kind       = "User"
    metadata = {
      name      = "alice"
      namespace = "default"
    }
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
  })

  wait_for_rollout = false
}
```

---

## Reading Status

Use the `kubectl_manifest` data source and decode its `json` attribute. Status fields are listed in the [API Reference](../../api-reference/overview.md).

```hcl
data "kubectl_manifest" "app_vm" {
  api_version = "compute.cloud.stakater.com/v1"
  kind        = "VirtualMachine"
  name        = "app-vm"
  namespace   = "default"
  depends_on  = [kubectl_manifest.app_vm]
}

output "app_vm_status" {
  value = try(jsondecode(data.kubectl_manifest.app_vm.json).status.vm.printableStatus, null)
}
```

---

## State Management

Import existing SCO claims into Terraform state. The ID separates `apiVersion`, `kind`, name and namespace with `//`:

```bash
terraform import kubectl_manifest.app_vm \
  "compute.cloud.stakater.com/v1//VirtualMachine//app-vm//default"
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
- [ArgoCD Setup](../gitops-access/argocd-setup.md) — Status of continuous deployment with ArgoCD or Flux
- [API Reference](../../api-reference/overview.md) — Full parameter reference for all services
