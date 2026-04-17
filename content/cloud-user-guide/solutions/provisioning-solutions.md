# Provisioning Solutions

Provisioning a service in SCO is the same as applying any Kubernetes resource — write a YAML claim and apply it. The platform handles the rest.

---

## Applying a Claim

Every service has its own resource kind and API group. Apply a claim with `kubectl`:

```bash
kubectl apply -f my-claim.yaml
```

For example, to provision a virtual machine:

```yaml
apiVersion: compute.cloud.stakater.com/v1
kind: VirtualMachine
metadata:
  name: my-dev-vm
spec:
  parameters:
    flavour: rhel9
    instanceType: o1.medium
    connection: private
    sshPublicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
```

---

## Monitoring Status

```bash
# Check status
kubectl get virtualmachine my-dev-vm

# Watch for changes
kubectl get virtualmachine my-dev-vm -w

# Full details and events
kubectl describe virtualmachine my-dev-vm
```

Typical provisioning times:

| Service | Typical time |
|---------|-------------|
| Virtual Machine | 2–5 minutes |
| OpenShift Cluster | 10–20 minutes |
| Database | 2–5 minutes |

---

## Updating a Service

Edit the claim and reapply:

```bash
kubectl apply -f my-updated-claim.yaml
```

Crossplane reconciles the change. Not all fields are mutable after creation — check the [API reference](../../api-reference/overview.md) for details.

---

## Deleting a Service

```bash
kubectl delete virtualmachine my-dev-vm
```

This triggers a full teardown of all resources backing the service. Deletion may take a few minutes.

!!! warning
    Deletion is irreversible. Any data stored in the service (VM disks, database contents) will be permanently removed. Back up any data you need before deleting.

---

## Troubleshooting Stuck Provisioning

If a service stays in `Provisioning` state longer than expected, check for errors:

```bash
kubectl describe virtualmachine my-dev-vm
```

Look at the **Conditions** and **Events** sections. Common causes:

- **Quota exceeded** — request a quota increase from your administrator
- **Invalid parameter** — a value was rejected; the error message will indicate which field
- **Infrastructure issue** — contact your platform administrator

See [Common Issues](../../troubleshooting/common-issues.md) for more.

---

## What's Next?

- [Provision a Virtual Machine](../../how-to-guides/user/provision-virtual-machine.md) — Full VM guide
- [Provision an OpenShift Cluster](../../how-to-guides/user/provision-openshift-cluster.md) — Full cluster guide
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure kubectl access
