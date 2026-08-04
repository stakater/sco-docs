# Choosing the Platform Secret Store Unseal Method

The platform's hub secret store (OpenBao) keeps its data encrypted at rest. On every start it must **unseal** — obtain the key that decrypts its storage — before it can serve any secret. Until it does, no platform component that depends on it can start.

SCO supports two unseal methods, chosen at install time:

| Method | Where the unseal key lives | Requires a cloud account |
|--------|----------------------------|:------------------------:|
| **`awskms`** (default) | An AWS KMS key; the platform holds only the credentials to call KMS | ✅ |
| **`static`** | A key you generate, stored as a Kubernetes Secret in the cluster | — |

Both unseal automatically on restart. Neither requires an operator to type anything when a pod cycles — which matters, because a sealed hub blocks the platform's other components.

!!! warning "This is a one-time, irreversible choice"
    The secret store records its unseal method inside its own encrypted storage the first time it is initialised, and afterwards **refuses to start** if the configuration disagrees. Changing the method later is a deliberate migration procedure, not a configuration edit — plan to get it right on the first install.

---

## Which one should you choose?

Choose **`awskms`** (the default) when the platform has an AWS account available. It is the better option whenever it is an option.

Choose **`static`** when the environment genuinely cannot reach a cloud KMS:

- Air-gapped or disconnected installations
- On-premises or sovereign deployments with no permitted cloud egress
- Customer policy that forbids a dependency on a third-party cloud service

---

## How they compare

### Security

The honest summary is that `static` is **weaker in one specific, important way**, and equivalent in most others.

With `awskms`, the key that decrypts the platform's secret store never exists inside the cluster. The cluster holds only credentials to *ask* AWS to unwrap it. An attacker who obtains a copy of the cluster's storage — an etcd backup, a stolen disk, a snapshot of a volume — still cannot read the secret store's contents, because the material that would decrypt it is not in what they took. They would also need working access to your AWS account.

With `static`, the unseal key is stored in the cluster alongside the data it protects. That means:

- **A single boundary protects both.** Anyone who can read cluster secrets at the highest privilege level, or who obtains a copy of cluster storage, holds everything needed to decrypt the secret store offline. There is no second system to defeat.
- **Backups become as sensitive as the live cluster.** Any backup of the cluster's underlying key-value store must be treated as if it were the secret store itself.
- **There is no external audit trail of unseal events**, and no way to cut off access from outside the cluster. With `awskms`, revoking the KMS grant instantly denies unsealing everywhere, and every unwrap attempt is recorded in your cloud audit log — independently of the cluster, so it survives a cluster compromise.

What `static` does **not** do is lower the bar for reaching the platform in the first place. Both methods store their material in the same place at rest, protect it with the same cluster access controls, and neither exposes the secret store to the network any differently. `static` removes a defence-in-depth layer against offline attack on stolen storage; it does not create a new way in.

!!! important "If you deploy `static`, protect these two things"
    Everything rests on them: the access controls governing who can read secrets in the platform's namespaces, and every copy of cluster storage — etcd backups, volume snapshots, disaster-recovery archives. Treat those backups with the same handling rules as the secret store's own contents, including encryption at rest and restricted retrieval.

### Operations

| | `awskms` | `static` |
|--|----------|----------|
| External dependency at boot | AWS KMS must be reachable | None |
| Network egress required | ✅ | — |
| Behaviour if the dependency is unavailable | Stays sealed until KMS is reachable | Not applicable |
| Key custody | AWS stores and durably retains the key material | You generate it, and you alone hold it — an offline copy outside the cluster is mandatory |
| Rotation | Managed through AWS KMS | Manual, with a documented n-1 window |
| Audit trail of unseal events | External, in the cloud audit log | Cluster events only |

`static` trades an external dependency for custody responsibility. It removes a boot-time network dependency and everything that can go wrong with one — expired credentials, revoked permissions, a regional outage leaving the platform sealed — and hands you the job of never losing a 32-byte key.

That last part is not a formality. With `awskms`, AWS keeps the key durable for you and a deleted key has a recovery window. With `static` there is no such safety net: if the cluster's copy is lost and you have no copy elsewhere, nothing can rebuild it. Decide where that offline copy lives, and who holds it, before you install — the procedure is in [step 1](#step-1-generate-the-unseal-key) below.

---

## Risks common to both methods

These apply whichever method you choose, and are worth understanding before you install.

!!! warning "Losing the unseal key means losing the data — backups will not save you"
    The recovery keys issued at initialisation **cannot** unseal an automatically-unsealed secret store. They exist for break-glass operations such as generating a root token or performing a seal migration. If the unseal key is destroyed — a deleted KMS key, or a lost static key — the secret store's contents are unrecoverable, and restoring a backup does not help, because the backup is encrypted with the same key.

**Keep custody of the recovery keys.** They are issued once, at initialisation, and cannot be regenerated afterwards. Distribute them to their holders and store them offline. They are never used during a normal restart, so offline custody costs nothing operationally.

**Never point an initialised secret store at a different key.** With either method, presenting a key that is not the one used at initialisation leaves it sealed. With `static` the failure names the key it expected and can be corrected by restoring that key, or by declaring it as the previous key during a rotation. Either way, the fix is to produce the original key — there is no way around it.

---

## Configuring the static method

!!! note "Version requirement"
    Static unseal requires **`ksp` v2.3.4 or later**. Earlier versions accept the setting and then ignore it, and because the method is fixed at initialisation, the resulting install cannot be corrected in place. Check with `ksp version` before you begin.

Static unseal is configured entirely at install time, through two of the `ksp up` inputs described in [OpenShift Installation](openshift.md).

### Step 1: Generate the unseal key

The key is 32 random bytes, base64-encoded:

```bash
openssl rand 32 | base64 -w0
```

!!! warning "Store this key outside the cluster before you install"
    **The copy in the cluster is a working copy, not a backup.** It can be deleted by accident, lost with the namespace, or missing from a restore — and the platform's secret store cannot be recovered without it. Put the key in an offline store *before* you run the installer: an enterprise password manager or secrets-management system that does not depend on this cluster, or sealed offline custody such as a printed copy in a safe. At least two holders, following whatever your organisation already does for root credentials.

Nothing in the platform can regenerate this key or recover it from the running secret store. If the in-cluster copy is lost and there is no external copy, every secret the platform holds is gone permanently — see the data-loss warning above. Re-running the installer later with a *different* key does not repair it; it permanently seals the platform.

Treat that external copy with the same care as the key itself: it decrypts the platform's entire secret store, so it belongs under the same access controls, approval, and audit as your most privileged credentials.

### Step 2: Seed the key as a cluster secret

Put the key in an extra-secrets file, applied by `ksp up --extra-secrets` before the secret store starts:

```yaml
secrets:
  - name: openbao-unseal-key
    namespace: stakater-openbao
    type: Opaque
    data:
      current: "<paste the step 1 output verbatim>"
```

!!! note
    Paste the output of step 1 exactly as it was printed — do **not** encode it again. The installer handles Kubernetes' own base64 encoding for you; the value in this file is the key as generated. The installer also creates the namespace if it does not yet exist.

### Step 3: Select the method in your environment config

In the values file you pass to `ksp up --environment-config`, add a `seal` block under `clusterDefaults`:

```yaml
name: cluster-defaults

clusterDefaults:
  # ... your other cluster defaults ...

  seal:
    type: static
    static:
      currentKeyId: "k1"
      secretName: openbao-unseal-key
```

| Field | Required | Default | Description |
|-------|:--------:|---------|-------------|
| `seal.type` | — | `awskms` | `awskms` or `static`. Any other value is rejected at render time. |
| `seal.static.currentKeyId` | ✅ when `type: static` | — | An opaque label for the current key. Change it whenever the key changes. |
| `seal.static.previousKeyId` | — | — | Set only during a rotation, alongside the previous key. |
| `seal.static.secretName` | — | `openbao-unseal-key` | Name of the secret seeded in step 2. |

`currentKeyId` is written into the secret store's storage at initialisation and identifies which key its data was encrypted with. It is a label, not a secret, and it is what makes a mismatched key produce a clear, self-describing error rather than an opaque failure.

### Step 4: Install and verify

Run `ksp up` as described in [OpenShift Installation](openshift.md), passing both files:

```bash
ksp up \
  -c kubestack-config-claim.yaml \
  -f kubestack-plus-claim.yaml \
  --environment-config env-config.yaml \
  --extra-secrets extra-secrets.yaml \
  --registry-secret registry-secret.yaml
```

Once the platform is up, confirm the secret store came up unsealed with the method you chose:

```bash
kubectl exec -n stakater-openbao openbao-0 -- bao status
```

Expect `Seal Type` to read `static` and `Sealed` to read `false`. In a highly-available deployment, check each replica — every one should report `Sealed false`, with one active and the rest standby.

!!! warning "Verify before you continue"
    If `Seal Type` reads `awskms` on an install you intended to be static, stop. The method is now fixed in storage and cannot be corrected by editing configuration. The usual cause is a `ksp` version below v2.3.4, or the `seal` block missing from the file passed to `--environment-config`.

---

## Rotating a static key

Rotation keeps the previous key available while the platform re-encrypts under the new one:

1. Generate a new key as in step 1 above.
1. In the seeded secret, move the existing value to a `previous` entry and put the new key in `current`.
1. Set `seal.static.previousKeyId` to the outgoing `currentKeyId`, and `currentKeyId` to a new label.
1. Let the platform reconcile, then restart the secret store's pods so they read the new configuration.
1. Once every replica reports unsealed, remove the `previous` entry and `previousKeyId`.

!!! note
    Configuration is read at process start, so a rotation mistake stays invisible until the next restart. Restart one replica deliberately and confirm it comes back unsealed before you remove the previous key.

---

## Changing methods on a running platform

Switching an already-initialised secret store between `awskms` and `static` is a **seal migration** — an explicit, planned procedure with downtime, not a configuration change. Editing the configuration on a running platform does not migrate it; it makes the secret store refuse to start on its next restart, which may not be noticed until hours or days later.

Contact Stakater support before attempting a migration.

---

## What's Next?

- [OpenShift Installation](openshift.md) — Step-by-step installation guide
- [Platform Configuration](configuration.md) — How platform configuration is applied after install
- [Components](../architecture/components.md) — The platform's secret management architecture
