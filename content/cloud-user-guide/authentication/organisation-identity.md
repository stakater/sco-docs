# One Identity Across Your Organisation

Every organisation on the platform has its own isolated identity realm, created automatically when the organisation is registered. One account in that realm signs you in everywhere the organisation reaches:

| Surface | How you sign in |
|---------|-----------------|
| SCO console | Organisation login page (your console URL) |
| Mesh dashboard | Same account, behind single sign-on |
| Mesh device enrolment | Browser single sign-on during `netbird up` |
| Vault UI and CLI | **Sign in with OIDC** / `bao login -method=oidc` |
| OpenShift cluster console | The organisation's identity provider button on the cluster login page |
| `oc` CLI | `oc login --web` (browser single sign-on) |

Credentials are scoped to the organisation: an account in one organisation cannot access another, even for the same email address.

---

## The Flow at a Glance

1. **Organisation registration** creates the realm and the first administrator account — the email used to register.
2. **Members are added** by an administrator (see [Managing Users](managing-users.md)). Each member receives initial credentials.
3. **First sign-in forces a password change.** Until a member completes it, the initial password is the only valid credential; after it, the initial password is dead.
4. From then on the same username and password work across every surface in the table above.

!!! note
    Your username is the full email address (for example `alice@acmecorp.example.com`), not the short name.

---

## Enrolling a Device into the Mesh

Device enrolment uses the same single sign-on. After [creating a Mesh](../../how-to-guides/user/create-mesh.md) (or if your organisation includes one by default):

```bash
netbird up --management-url=<your mesh management URL>
```

The command opens a browser window for single sign-on and **waits for the result on a local callback port**. Two things follow from that:

- **Leave `netbird up` running in the foreground** until the browser flow completes. If the process stops waiting — because it was interrupted, or because the sign-in took too long (a forced first-login password change can do this) — the browser's final redirect lands on a closed port and shows *"localhost refused to connect"*. The sign-in itself succeeded; simply run `netbird up` again and complete the (now faster) flow.
- **The browser that opens shares your existing session.** If you are already signed in as a different user — common when testing with a second account — the enrolment silently registers the device to that user. Copy the printed URL into a private/incognito window to choose the identity explicitly.

### Multiple accounts on one machine

The NetBird client supports profiles, so you never need to wipe state to switch identities:

```bash
netbird profile add alice-work
netbird profile select alice-work
netbird up --management-url=<your mesh management URL>
```

Switch back with `netbird profile select default` (disconnect first with `netbird down`), and remove test profiles with `netbird profile remove <name>`.

---

## Signing in to Services over the Mesh

With a device enrolled, the organisation's published services resolve and authenticate with the same account:

- **Vault** — open `https://bao.<organisation>.mesh.<cluster-domain>` and use **Sign in with OIDC**, or from the CLI:

    ```bash
    export VAULT_ADDR=https://bao.<organisation>.mesh.<cluster-domain>
    bao login -method=oidc
    ```

- **Private OpenShift clusters** — the cluster console and API are published to Mesh peers. On the console login page, click your organisation's identity provider button (do **not** type your credentials into the cluster's native username/password prompt — that prompt is for local cluster accounts and your organisation credentials will be rejected there). For the CLI, use `oc login --web`, which runs the same browser flow.

!!! tip
    If a cluster's login page shows **no** identity provider button at all, the cluster cannot reach your organisation's identity realm — contact your platform administrator rather than retrying credentials.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| *localhost refused to connect* after device-enrolment sign-in | The `netbird up` process was no longer waiting on its callback port | Run `netbird up` again and complete the browser flow while it waits |
| Device enrolled as the wrong user | The browser reused an existing session | Re-enrol using the printed URL in a private window |
| *Incorrect username or password* on a cluster console | Credentials typed into the cluster's native prompt instead of the organisation's identity provider button | Use the identity provider button; native prompts are for local cluster accounts |
| Initial password rejected | It was already consumed by the forced first-login change | Use the password set at first login, or ask an administrator to reset |

## Related

- [Logging In](logging-in.md)
- [Managing Users](managing-users.md)
- [How to Create a Mesh](../../how-to-guides/user/create-mesh.md)
- [How to Create a Vault](../../how-to-guides/user/create-vault.md)
