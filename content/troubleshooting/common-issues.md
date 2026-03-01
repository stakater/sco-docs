# Common Issues

Solutions to the most frequently encountered problems in SCO.

---

## Authentication and Access

### "Unable to connect to the server" or kubeconfig errors

**Cause:** Expired token, wrong context, or incorrect server URL.

```bash
kubectl config current-context

# Re-download kubeconfig from the console and set it
export KUBECONFIG=~/.kube/my-project-new.yaml
kubectl cluster-info
```

Clear a cached OIDC token if using `oidc-login`:

```bash
rm -rf ~/.kube/cache/oidc-login/
```

---

### "Forbidden" when applying a claim

**Cause:** Your role in this project doesn't permit creating resources.

**Fix:** Contact your organisation administrator — you need `edit` or `admin` role to create resources.

---

### Cannot log in to the console

**Cause:** Wrong organisation URL, locked account, or SSO misconfiguration.

**Fix:** Ensure you're using the console URL for your specific organisation. If your account is locked after failed attempts, an administrator can unlock it.

---

## Provisioning

### Claim stays in `Provisioning`

**Cause:** A composed resource is failing to reconcile.

```bash
kubectl describe <kind> <name>
# Check Conditions and Events sections
```

Common causes:
- **Quota exceeded** — see below
- **Invalid parameter** — the error message identifies which field
- **Infrastructure capacity** — contact your platform administrator

---

### "Exceeded quota" error

```bash
kubectl describe resourcequota
```

Request a quota increase from your organisation administrator.

---

### Claim stuck deleting

**Cause:** Deletion is ordered — all composed resources must be removed before the claim disappears. This is expected behaviour.

VMs typically delete in under a minute. OpenShift clusters may take 5–10 minutes.

If stuck for more than 15 minutes, contact your platform administrator.

---

## Virtual Machines

### VM Ready but SSH connection refused

**Cause:** Cloud-init still running, wrong IP, or firewall issue.

**Fix:** Wait 2–3 minutes after `Ready` for cloud-init to complete, then retry.

```bash
kubectl get virtualmachine my-vm -o jsonpath='{.status}'
ssh -i ~/.ssh/my-key user@<vm-ip>
```

If using `connection: private`, the VM IP is only reachable from within the cluster. Use `connection: public` for external access.

---

### Cloud-init script didn't run

**Cause:** Syntax error in `cloudInit.userData`.

**Fix:** The file must start with `#cloud-config`. Validate your cloud-init YAML before applying.

---

## OpenShift Clusters

### Cluster provisioning taking more than 20 minutes

Hosted cluster provisioning takes 10–25 minutes for first-time setup. Monitor progress:

```bash
kubectl get openshiftcluster my-cluster -w
kubectl describe openshiftcluster my-cluster
```

If no progress after 30 minutes, contact your platform administrator.

---

### Cluster kubeconfig shows empty status

**Cause:** Cluster hasn't finished provisioning yet.

**Fix:** Wait for `Ready: True`, then check status for connection details:

```bash
kubectl get openshiftcluster my-cluster -o jsonpath='{.status}'
```

---

## IAM and Users

### User created but cannot log in

**Cause:** `enabled` or `emailVerified` not set to `true`.

```bash
kubectl get user alice -o yaml
```

Ensure both fields are `true`. Update the claim and reapply.

---

### User removed from group but still has access

**Cause:** Token caching — the existing session still carries old group membership.

**Fix:** The user must log out and back in to get a refreshed token. This resolves automatically at next login.

---

## What's Next?

- [Troubleshooting Overview](overview.md) — Layer-by-layer diagnostic approach
- [Provisioning Solutions](../cloud-user-guide/solutions/provisioning-solutions.md) — Provisioning guide
