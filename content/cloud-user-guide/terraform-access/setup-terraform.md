# Setup Terraform

Terraform can manage resources in your SCO project using the Kubernetes provider. The same project kubeconfig used by `kubectl` provides Terraform with access.

---

## Prerequisites

- Terraform installed ([official install guide](https://developer.hashicorp.com/terraform/install))
- Your project kubeconfig (see [Setup kubectl](../kubectl-access/setup-kubectl.md))

---

## Step 1: Configure the Provider

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand("~/.kube/my-project.yaml")
  config_context = "my-project"
}
```

Or use the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=~/.kube/my-project.yaml
```

```hcl
provider "kubernetes" {}
```

---

## Step 2: Provision a Service

Use `kubernetes_manifest` to apply SCO claims:

```hcl
resource "kubernetes_manifest" "dev_vm" {
  manifest = {
    apiVersion = "compute.cloud.stakater.com/v1"
    kind       = "VirtualMachine"
    metadata = {
      name = "dev-vm"
    }
    spec = {
      parameters = {
        flavour      = "rhel9"
        instanceType = "o1.medium"
        connection   = "private"
        sshPublicKey = var.ssh_public_key
      }
    }
  }

  timeouts {
    create = "10m"
    delete = "10m"
  }
}
```

Apply:

```bash
terraform init
terraform plan
terraform apply
```

---

## Step 3: Read Status

```hcl
data "kubernetes_resource" "dev_vm" {
  api_version = "compute.cloud.stakater.com/v1"
  kind        = "VirtualMachine"
  metadata {
    name = "dev-vm"
  }
}

output "vm_status" {
  value = data.kubernetes_resource.dev_vm.object.status
}
```

---

## What's Next?

- [Kubernetes Provider](kubernetes-provider.md) — Advanced patterns and multiple project configuration
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — SCO claim structure reference
- [API Reference](../../api-reference/overview.md) — Full parameter reference for all services
