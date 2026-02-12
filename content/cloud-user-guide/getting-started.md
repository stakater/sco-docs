# Getting Started for Cloud Users

Quick start guide for developers and teams using Stakater Cloud Orchestrator.

Emma is a developer at ACME Corporation who needs to provision a virtual machine for her development environment. SCO, running on their organization's Kubernetes infrastructure, provides self-service access to VMs and Kubernetes clusters. This guide walks through the essential steps to get started with SCO as a cloud user.

## Prerequisites

Before you begin, you need:

- Access to your organization's SCO platform
- Login credentials provided by your platform administrator
- Basic understanding of Kubernetes concepts (optional but helpful)

## Step 1: Log In to Your Organization

Navigate to your organization's SCO console URL (provided by your administrator).

Log in using your credentials. Each organization has its own isolated authentication realm, so you'll only see resources within your organization.

!!! note
    Your administrator will provide the console URL and initial login credentials. You may be able to use SSO if configured.

## Step 2: Create Your First Project

Projects are isolated environments where you deploy your applications and provision services.

### Using the Console

1. Navigate to "Projects" in the sidebar
2. Click "Create Project"
3. Enter project details:
    - **Name**: `my-app-dev`
    - **Display Name**: "My Application - Development"
    - **Description**: "Development environment for my application"
4. Click "Create"

### Using kubectl

Alternatively, create a project using kubectl:

```yaml
apiVersion: tenancy.stakater.com/v1alpha1
kind: Project
metadata:
    name: my-app-dev
spec:
    displayName: "My Application - Development"
    description: "Development environment for my application"
```

```bash
kubectl apply -f project.yaml
```

Emma can verify her project was created:

```bash
kubectl get projects
```

Expected output:

```
NAME          DISPLAY NAME                   STATUS   AGE
my-app-dev    My Application - Development   Ready    30s
```

## Step 3: Browse the Marketplace

Explore available services in the marketplace.

### Using the Console

1. Navigate to "Marketplace" in the sidebar
2. Browse available solutions
3. View solution details, documentation, and configuration options

### Using kubectl

List available solutions:

```bash
kubectl get solutions
```

View details about a specific solution:

```bash
kubectl describe solution postgresql
```

## Step 4: Provision a Virtual Machine

Let's provision a virtual machine for Emma's development environment.

### Using the Console

1. In the marketplace, click on "Virtual Machine"
2. Click "Provision"
3. Select your project: `my-app-dev`
4. Configure the VM:
    - **Name**: `my-dev-vm`
    - **Instance Type**: `o1.medium` (2 vCPU, 4GB RAM)
    - **Connection**: `private`
    - **SSH Public Key**: Paste your SSH public key
5. Click "Create"

### Using kubectl

Create a VirtualMachine with a YAML manifest:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
    name: my-dev-vm
    namespace: my-app-dev
spec:
    parameters:
        instanceType: o1.medium
        connection: private
        sshPublicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
        cloudInit:
            userData: |
                #cloud-config
                packages:
                  - git
                  - curl
                  - vim
```

```bash
kubectl apply -f vm.yaml
```

Emma can monitor the provisioning:

```bash
kubectl get virtualmachine -n my-app-dev

kubectl describe virtualmachine my-dev-vm -n my-app-dev
```

Wait for the VM to be ready:

```
NAME        INSTANCE-TYPE   STATUS   AGE
my-dev-vm   o1.medium       Ready    3m
```

### Access Your VM

Once ready, get connection details:

```bash
kubectl get vm my-dev-vm -n my-app-dev -o jsonpath='{.status.connection}'
```

SSH into the VM:

```bash
ssh user@<vm-ip-address>
```

## Step 5: Access via kubectl

Get your project's kubeconfig to work with kubectl locally.

### Download Kubeconfig

From the console:

1. Navigate to your project
2. Click "Settings" or "Access"
3. Click "Download Kubeconfig"

Save the file as `~/.kube/my-app-dev-config`

### Use the Kubeconfig

```bash
export KUBECONFIG=~/.kube/my-app-dev-config

kubectl get postgresql
```

Emma can now interact with her project using kubectl!

!!! tip
    You can merge this kubeconfig with your existing `~/.kube/config` file or use the `KUBECONFIG` environment variable to switch between contexts.

## What You've Accomplished

Emma has now:

✅ Logged in to her organization
✅ Created a project for her application
✅ Browsed the marketplace
✅ Provisioned a virtual machine
✅ Set up kubectl access to her project
✅ Accessed her VM via SSH

## Next Steps

Now that you have the basics, explore more features:

- [Project Structure](projects/project-structure.md) - Understand project isolation
- [Terraform Access](terraform-access/setup-terraform.md) - Use Terraform with SCO
- [GitOps Access](gitops-access/argocd-setup.md) - Set up continuous deployment
- [Managing Users](authentication/managing-users.md) - Invite team members

## Common Tasks

**Provision OpenShift Clusters**: Request full OpenShift clusters for your team using the OpenShiftCluster solution.

**Provision Additional VMs**: Create more VMs with different instance types (compute-optimized, memory-optimized, etc.).

**Create Multiple Projects**: Separate environments for dev, staging, and production.

**Add Custom Solutions**: If your platform team has published additional solutions (databases, message queues, etc.), provision them from the marketplace.

**Invite Team Members**: Add collaborators to your projects.

## What's Next?

- [Creating Projects](projects/creating-projects.md) - Detailed project creation guide
- [Browsing Marketplace](solutions/browsing-marketplace.md) - Explore available solutions
- [Setup kubectl](kubectl-access/setup-kubectl.md) - Configure kubectl access
