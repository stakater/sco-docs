# How to Deploy Your First Application

Learn how to deploy an application on a private virtual machine in its own project, using SCO services.

Emma, a developer at ACME Corp, needs to deploy her application on a virtual machine in a dedicated project, where only her team can manage it and nothing is exposed to the internet.

## Overview

Deploying an application on SCO involves four main steps:

1. **Set up identity** — Create the users and groups who will access the application environment
1. **Create a project** — Provision an isolated project with its own network, and grant your team access
1. **Provision compute with your application** — Deploy a virtual machine that installs and starts your application
1. **Reach the application** — Connect to it privately over your organisation's Mesh

!!! note
    Steps 1 and 2 need an organisation administrator. Steps 3 and 4 can be done by any project member with the `compute-user` role.

!!! warning "Current limitations"
    Reaching an application privately over the Mesh does **not** work end to end yet. A VM's built-in Mesh Route opens only SSH (tcp/22), RDP (tcp/3389) and ICMP, not application ports such as `8080`, so the interim way to reach an application is an SSH tunnel (Step 4). That tunnel depends on the Mesh Route delivering SSH traffic to the VM, which it does not do yet (tracked as SA-9273), so Step 4 currently times out. A [MeshRouter](../../api-reference/public-apis/mesh-router.md) with a [MeshPolicy](../../api-reference/public-apis/mesh-policy.md) cannot reach project workloads either (tracked as SA-9272; see [Expose an Internal Service via the Mesh](expose-service-via-mesh.md)).

## Prerequisites

- The `user.iam.cloud.stakater.com`, `group.iam.cloud.stakater.com`, `project.tenant.cloud.stakater.com` and `virtualmachine.compute.cloud.stakater.com` APIs available
- `kubectl` configured with your organisation project kubeconfig (Steps 1–2) and, once it exists, the new project's kubeconfig (Steps 3–4)
- A [Mesh](create-mesh.md) in your organisation, and a laptop enrolled on it
- An SSH key pair

## What Gets Created

Following this guide, the platform provisions:

- **Organisation users and a group** in your organisation's IDP
- **A project** with its own private network, and role-based access for your group
- **A private virtual machine** running your application, advertised to your organisation's Mesh

## Step 1: Create Users and Groups

Before creating a project, set up identity resources for your team.

Create a user for each team member:

```bash
# See: How to Create an IAM User
kubectl apply -f user.yaml
```

Organise users into a group. Add each member by their **email address**:

```yaml
apiVersion: iam.cloud.stakater.com/v1
kind: Group
metadata:
  name: developers
spec:
  parameters:
    name: developers
    members:
      - emma@acmecorp.example.com
```

```bash
kubectl apply -f group.yaml
```

!!! note
    Users sign in with their email address, and the organisation IDP identifies them by it. Use the email — not the user claim's `username` — wherever you name a user: in group `members` and in a project's `access[].users`. A name that does not match keeps the group from becoming Ready, or grants the user nothing.

See the dedicated guides for full details:

- [Create an IAM User](create-iam-user.md)
- [Create an IAM Group](create-iam-group.md)

## Step 2: Create a Project

Create a project to isolate your application's resources, and grant your team the `compute-user` role:

```yaml
apiVersion: tenant.cloud.stakater.com/v1
kind: Project
metadata:
  name: my-app-dev
spec:
  parameters:
    network:
      cidr: 10.100.0.0/16
    access:
      - role: compute-user
        groups:
          - developers
```

```bash
kubectl apply -f project.yaml
```

`compute-user` lets members create and manage virtual machines in the project, and gives the group SSH access to the project's VMs over the Mesh. VM access over the Mesh is granted to **groups**, not to individual users, so grant the role to a group even for a single person. You can also grant a role to an individual user by email (`users: [emma@acmecorp.example.com]`), but that user does not get Mesh access to the VMs.

!!! note
    Grant the least-privileged role that does the job. Do **not** use `cluster-admin` in `access`: it gives full control of the project, including granting access to others and deleting it.

See the full guide: [Create a Project](create-project.md)

## Step 3: Provision a Virtual Machine with Your Application

Switch to the new project's kubeconfig (see [Set Up kubectl Access](../../cloud-user-guide/kubectl-access/setup-kubectl.md)). Deploy a VM whose cloud-init installs and starts a small web application on port `8080`, and turn on its Mesh Route:

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
    meshRoute:
      enabled: true
    sshPublicKey:
      data: <base64-encoded-ssh-public-key>
    cloudInit:
      userData: |
        #cloud-config
        packages:
          - git
          - curl
        write_files:
          - path: /opt/app/index.html
            content: "Hello from app-server\n"
        runcmd:
          - [bash, -c, "cd /opt/app && nohup python3 -m http.server 8080 >/var/log/app.log 2>&1 &"]
          - [bash, -c, "firewall-cmd --add-port=8080/tcp || true"]
```

```bash
kubectl apply -f vm.yaml
```

Replace the `write_files` and `runcmd` entries with the commands that install and start your own application.

Wait for the VM to be Ready and note its private IP address:

```bash
kubectl get virtualmachine app-server
kubectl get virtualmachine app-server -o jsonpath='{.status.vm.internalIP}'
```

See the full guide: [Provision a Virtual Machine](provision-virtual-machine.md)

## Step 4: Reach the Application over the Mesh

The application is private: it has no public address, and the Mesh Route opens SSH but not port `8080`. Reach it through an SSH tunnel over the Mesh.

1. On your laptop, sign in to the Mesh as a member of the `developers` group, so the Mesh Route is allowed for you.
1. Open a tunnel from local port `8080` to the application on the VM:

    ```bash
    ssh -L 8080:localhost:8080 cloud-user@<vm-internal-ip>
    ```

1. In another terminal, call the application:

    ```bash
    curl http://localhost:8080/
    ```

    Expected output: `Hello from app-server`

!!! note
    This step depends on the Mesh Route delivering SSH traffic to the VM, which is not working yet (tracked as SA-9273). If `ssh` times out, that is the cause — see the limitations at the top of this guide.

<!-- TODO(SA-8708): the SSH-tunnel path has not been verified end to end (blocked by SA-9273). Re-test Step 4 once it is fixed, and remove the limitation notes. -->

## What's Next?

- [Create a Project](create-project.md) - Detailed project creation guide
- [Create an IAM User](create-iam-user.md) - Provision user accounts
- [Create an IAM Group](create-iam-group.md) - Organise users into groups
- [Provision a Virtual Machine](provision-virtual-machine.md) - Deploy compute resources
- [Expose an Internal Service via the Mesh](expose-service-via-mesh.md) - Publish your own services to Mesh peers
- [Provision an OpenShift Cluster](provision-openshift-cluster.md) - Deploy an OpenShift cluster
- [Getting Started](../../cloud-user-guide/getting-started.md) - Cloud user quick start
