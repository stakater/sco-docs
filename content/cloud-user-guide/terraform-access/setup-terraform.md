# Setup Terraform

Terraform (or OpenTofu) can manage resources in your SCO project with the same project kubeconfig you use for `kubectl`. Terraform signs in as you, so it can do exactly what your project role allows.

This is the supported way to manage project resources programmatically today. Continuous deployment tools such as ArgoCD and Flux need an automation identity, which is not available yet; see [ArgoCD Setup](../gitops-access/argocd-setup.md).

---

## Prerequisites

- Terraform ([official install guide](https://developer.hashicorp.com/terraform/install)) or OpenTofu
- Your project kubeconfig (see [Setup kubectl](../kubectl-access/setup-kubectl.md))
- A working `kubectl` login with that kubeconfig. Terraform reuses the same login, so run any `kubectl` command first if your session has expired.

!!! note
    Use the `alekc/kubectl` provider, as shown below. The `hashicorp/kubernetes` provider (`kubernetes_manifest`, `data "kubernetes_resource"`) does not work for project users: it needs to read the API schemas directly, which project users are not allowed to do, and fails with a `customresourcedefinitions ... is forbidden` error.

---

## Step 1: Configure the Provider

Find the context name in your project kubeconfig:

```bash
kubectl config get-contexts --kubeconfig ~/.kube/my-project.yaml
```

The kubeconfig downloaded from the console has a single context named `dev`. Use the name the command prints.

```hcl
terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.4"
    }
  }
}

provider "kubectl" {
  config_path      = pathexpand("~/.kube/my-project.yaml")
  config_context   = "dev"
  load_config_file = true
}
```

Or set the `KUBECONFIG` environment variable and leave `config_path` out:

```bash
export KUBECONFIG=~/.kube/my-project.yaml
```

```hcl
provider "kubectl" {
  load_config_file = true
}
```

---

## Step 2: Provision a Service

Use `kubectl_manifest` to apply SCO claims. Write the claim with `yamlencode` so Terraform checks the structure for you:

```hcl
variable "ssh_public_key" {
  description = "OpenSSH public key, for example the contents of ~/.ssh/id_ed25519.pub"
  type        = string
}

resource "kubectl_manifest" "dev_vm" {
  yaml_body = yamlencode({
    apiVersion = "compute.cloud.stakater.com/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = "dev-vm"
      namespace = "default"
    }
    spec = {
      parameters = {
        flavour      = "rhel9"
        instanceType = "o1.medium"
        connection   = "private"
        sshPublicKey = {
          data = base64encode(var.ssh_public_key)
        }
      }
    }
  })

  wait_for_rollout = false
}
```

Two details differ from the `kubectl` examples elsewhere in these docs:

- **`namespace = "default"` is required.** `kubectl` fills it in for you; Terraform does not, and refuses the claim without it (`Resources of type VirtualMachine require a namespace`).
- **`sshPublicKey` is an object**, with the OpenSSH public key base64-encoded in `data`. A plain string is rejected.

Apply:

```bash
terraform init
terraform plan
terraform apply
```

---

## Step 3: Read Status

Read the claim back with the `kubectl_manifest` data source and decode its `json` attribute:

```hcl
data "kubectl_manifest" "dev_vm" {
  api_version = "compute.cloud.stakater.com/v1"
  kind        = "VirtualMachine"
  name        = "dev-vm"
  namespace   = "default"
  depends_on  = [kubectl_manifest.dev_vm]
}

output "vm_ready" {
  value = try([for c in jsondecode(data.kubectl_manifest.dev_vm.json).status.conditions : c.status if c.type == "Ready"][0], null)
}

output "vm_status" {
  value = try(jsondecode(data.kubectl_manifest.dev_vm.json).status.vm.printableStatus, null)
}
```

The VM takes a few minutes to become ready. Run `terraform apply` again to refresh the outputs.

---

## Step 4: Clean Up

```bash
terraform destroy
```

This deletes the claim, and the platform removes the VM.

---

## What's Next?

- [Kubernetes Provider](kubernetes-provider.md) — More services, multiple projects and state management
- [Provisioning Solutions](../solutions/provisioning-solutions.md) — SCO claim structure reference
- [API Reference](../../api-reference/overview.md) — Full parameter reference for all services
