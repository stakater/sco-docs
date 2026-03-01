# How to Deploy Your First Application

Learn how to deploy an application using SCO services.

Emma, a developer at ACME Corp, needs to deploy her application with a virtual machine and a dedicated project.

## Overview

Deploying an application on SCO involves three main steps:

1. **Set up identity** — Create the users and groups who will access the application environment
2. **Create a project** — Provision an isolated project with network and quota configuration
3. **Provision compute** — Deploy the virtual machines or clusters your application needs

## Step 1: Create Users and Groups

Before creating a project, set up identity resources for your team.

Create a user for each team member:

```bash
# See: How to Create an IAM User
kubectl apply -f user.yaml
```

Organise users into a group:

```bash
# See: How to Create an IAM Group
kubectl apply -f group.yaml
```

See the dedicated guides for full details:

- [Create an IAM User](create-iam-user.md)
- [Create an IAM Group](create-iam-group.md)

## Step 2: Create a Project

Create a project to isolate your application's resources:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: my-app-dev
spec:
  parameters:
    name: my-app-dev
    network:
      name: app-network
      cidr: 10.100.0.0/16
    tenantQuota: small
    access:
      - role: cluster-admin
        users:
          - emma@acmecorp.example.com
      - role: view
        groups:
          - developers
```

```bash
kubectl apply -f project.yaml
```

See the full guide: [Create a Project](create-project.md)

## Step 3: Provision a Virtual Machine

Deploy a VM in your new project:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: app-server
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.medium
    storageSize: medium
    connection: private
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
    cloudInit:
      userData: |
        #cloud-config
        packages:
          - git
          - curl
```

```bash
kubectl apply -f vm.yaml
```

See the full guide: [Provision a Virtual Machine](provision-virtual-machine.md)

## What's Next?

- [Create a Project](create-project.md) - Detailed project creation guide
- [Create an IAM User](create-iam-user.md) - Provision user accounts
- [Create an IAM Group](create-iam-group.md) - Organise users into groups
- [Provision a Virtual Machine](provision-virtual-machine.md) - Deploy compute resources
- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Deploy an OpenShift cluster
- [Getting Started](../../cloud-user-guide/getting-started.md) - Cloud user quick start
