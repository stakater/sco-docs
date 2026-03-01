# Troubleshooting Overview

SCO is built on Kubernetes — debugging follows familiar Kubernetes patterns at each layer of the stack. This page explains where to look and what tools to use when something isn't working.

---

## The Debugging Layers

Problems in SCO typically occur at one of four layers:

```
1. Virtual API layer     Consumer claims, kubeconfig, authentication
2. Composition layer     Claim → composed resources → managed resources
3. Infrastructure layer  VMs, clusters, databases — the actual services
4. Tenancy layer         Namespaces, quotas, network policies
```

Identify which layer is affected, then focus your investigation there.

---

## Layer 1: Virtual API Layer

**Symptoms:** `kubectl` commands fail, claims cannot be applied, authentication errors.

```bash
# Test connectivity
kubectl cluster-info

# Check available resource types
kubectl api-resources | grep cloud.stakater.com

# Check claim status
kubectl get virtualmachine my-vm
kubectl describe virtualmachine my-vm
```

Common causes:
- Expired kubeconfig token → re-authenticate via the console
- Wrong context → `kubectl config current-context`
- API type not available → contact your administrator (the API may not be published)

---

## Layer 2: Composition Layer

**Symptoms:** Claims are accepted but stay in `Provisioning` or move to `Failed`.

```bash
# Check claim status and events
kubectl describe virtualmachine my-vm
# Look at: Conditions, Events sections
```

If events are sparse, the issue is in the composed resources on the service cluster. Contact your platform administrator with the full `kubectl describe` output and the time the issue started.

---

## Layer 3: Infrastructure Layer

**Symptoms:** Claim shows `Ready: True` but the service isn't functioning.

```bash
# Check status fields
kubectl get virtualmachine my-vm -o yaml | grep -A 20 status
kubectl get openshiftcluster my-cluster -o yaml | grep -A 30 status
```

If the claim is Ready but the service is inaccessible, this may be a networking or infrastructure-level failure. Contact your platform administrator with the status output.

---

## Layer 4: Tenancy Layer

**Symptoms:** Quota errors during provisioning, unexpected network connectivity failures.

```bash
# Check quota usage
kubectl describe resourcequota
```

If you've hit your quota, request an increase from your organisation administrator. Network isolation between projects is enforced by design — cross-project traffic is blocked.

---

## General Diagnostic Commands

```bash
# View all resources in your project
kubectl get all

# Recent events (errors shown here first)
kubectl get events --sort-by='.lastTimestamp'

# Full details for any resource
kubectl describe <kind> <name>

# Check quota limits and usage
kubectl describe resourcequota

# Verify available API types
kubectl api-resources | grep cloud.stakater.com
```

---

## What's Next?

- [Common Issues](common-issues.md) — Solutions to the most frequently encountered problems
