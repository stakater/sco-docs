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
1. **Members are added** by an administrator (see [Managing Users](managing-users.md)). Each member receives initial credentials.
1. **First sign-in forces a password change.** Until a member completes it, the initial password is the only valid credential; after it, the initial password is dead.
1. From then on the same username and password work across every surface in the table above.

!!! note
    Your username is the full email address (for example `alice@acmecorp.example.com`), not the short name.

---

## Enrolling a Device into the Mesh

Device enrolment uses the same single sign-on. After [creating a Mesh](../../how-to-guides/user/create-mesh.md) (or if your organisation includes one by default):

```bash
netbird up --management-url=<your organisation's management URL> --mtu 1200
```

The exact command — including your organisation's management URL — is shown in the Mesh dashboard under **Add Peer**. Add `--mtu 1200` to it; without it the connection comes up and then fails in a way that is easy to misread — see [Set the MTU when you enrol](#set-the-mtu-when-you-enrol) below.

The command opens a browser window for single sign-on and **waits for the result on a local callback port**. Two things follow from that:

- **Leave `netbird up` running in the foreground** until the browser flow completes. If the process stops waiting — because it was interrupted, or because the sign-in took too long (a forced first-login password change can do this) — the browser's final redirect lands on a closed port and shows *"localhost refused to connect"*. The sign-in itself succeeded; simply run `netbird up` again and complete the (now faster) flow.
- **The browser that opens shares your existing session.** If you are already signed in as a different user — common when testing with a second account — the enrolment silently registers the device to that user. Copy the printed URL into a private/incognito window to choose the identity explicitly.

### Set the MTU when you enrol

Pass `--mtu 1200` when you enrol. Without it the Mesh connects, the dashboard shows your device, and small requests succeed — but **anything larger stops arriving**. A TLS handshake sends a certificate chain of several kilobytes, so in practice web consoles and `kubectl`/`oc` hang and eventually time out, with no error to explain why. Bulk transfers such as `scp` behave the same way.

The value is set once and stored against the profile, so later `netbird up` runs keep it. Two consequences worth knowing:

- Changing it needs a disconnect first — `netbird up --mtu …` is ignored while the client is already connected:

    ```bash
    netbird down && netbird up --mtu 1200
    ```

- A new machine, a fresh profile, or a reinstall starts from the default again, so each device needs this once.

You can confirm the setting took effect with `ip link show wt0`, which should report `mtu 1200`.

### Multiple accounts on one machine

The NetBird client supports profiles, so you never need to wipe state to switch identities:

```bash
netbird profile add alice-work
netbird profile select alice-work
netbird up --management-url=<your organisation's management URL> --mtu 1200
```

Switch back with `netbird profile select default` (disconnect first with `netbird down`), and remove test profiles with `netbird profile remove <name>`. The MTU is stored per profile, so set it on each one you create.

---

## Signing in to Services over the Mesh

With a device enrolled, the organisation's published services resolve and authenticate with the same account:

- **Vault** — open `https://bao.<organisation>.mesh.<cluster-domain>` and use **Sign in with OIDC**, or from the CLI:

    ```bash
    export VAULT_ADDR=https://bao.<organisation>.mesh.<cluster-domain>
    bao login -method=oidc
    ```

- **Private OpenShift clusters** — the cluster console and API are published to Mesh peers. On the console login page, click your organisation's identity provider button (do **not** type your credentials into the cluster's native username/password prompt — that prompt is for local cluster accounts and your organisation credentials will be rejected there). For the CLI, use `oc login --web`, which runs the same browser flow.

    A private cluster's hostnames resolve from anywhere, but they point at addresses routable only from inside the Mesh — so without the Mesh connected the name resolves and the connection then hangs. That is the expected behaviour, not a broken cluster.

    Reaching a private cluster and having a role on it are **two separate grants**, and both come from the same `access.groups` entry on the cluster. If you can open the console but land on an empty "Hello, world" page, you have network access and no role yet. If the console will not load at all, the Mesh is the part to check. See [the OpenShift Cluster guide](../../how-to-guides/user/provision-openshift-cluster.md#access-grants).

!!! tip
    If a cluster's login page shows **no** identity provider button at all, the cluster cannot reach your organisation's identity realm — contact your platform administrator rather than retrying credentials.

!!! note "A new access group works only after its first member signs in"
    An access group becomes usable on the Mesh the first time one of its members completes an interactive sign-in — the group is created from your sign-in token rather than from configuration. So on a newly granted group, or a newly created private cluster, the first sign-in can take up to a minute to take effect and the cluster appears unreachable until it does. Everyone after the first is unaffected. Nothing needs requesting; just sign in once and retry.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| *localhost refused to connect* after device-enrolment sign-in | The `netbird up` process was no longer waiting on its callback port | Run `netbird up` again and complete the browser flow while it waits |
| Device enrolled as the wrong user | The browser reused an existing session | Re-enrol using the printed URL in a private window |
| *Incorrect username or password* on a cluster console | Credentials typed into the cluster's native prompt instead of the organisation's identity provider button | Use the identity provider button; native prompts are for local cluster accounts |
| Initial password rejected | It was already consumed by the forced first-login change | Use the password set at first login, or ask an administrator to reset |
| Private cluster console never loads; the hostname resolves | The Mesh is not connected, or your group has not been granted access to that cluster | Connect the Mesh (`netbird status`), then check your group is listed under the cluster's `access.groups` |
| Console or `oc` hangs and times out, but the Mesh is connected and `netbird status` looks healthy | The MTU was not set at enrolment, so large responses never arrive | `netbird down && netbird up --mtu 1200`, then retry — see [Set the MTU when you enrol](#set-the-mtu-when-you-enrol) |
| Signed in to a private cluster but the console is an empty *"Hello, world"* | Network access without a role — the two are separate grants | Ask for your group to be added to the cluster's `access.groups` with a role |

## Related

- [Logging In](logging-in.md)
- [Managing Users](managing-users.md)
- [How to Create a Mesh](../../how-to-guides/user/create-mesh.md)
- [How to Create a Vault](../../how-to-guides/user/create-vault.md)
