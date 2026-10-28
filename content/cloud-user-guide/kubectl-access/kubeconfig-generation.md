# kubeconfig Generation

This page explains the structure of your project kubeconfig and how authentication works against SCO project endpoints.

---

## Where to Get Your kubeconfig

Always use the kubeconfig the platform generates for your project. It is the only reliable source of the endpoint, certificate and login settings for your organisation — do not assemble one by hand from the example below.

**From the console:**

1. Open your project in the console
1. Switch the page from **Standard** to **Advanced** (top right)
1. In the **Access Configuration** section, open the kubeconfig <!-- TODO(SA-8708): confirm the exact label of the control in Access Configuration that opens the "Kubeconfig Base64" dialog -->
1. In the dialog, choose **Decoded** and copy the YAML into a file, for example `~/.kube/<project-name>.yaml`

!!! warning
    The dialog is titled `Kubeconfig Base64` and can also show the **Encoded** form, a single line of base64 text. `kubectl` cannot read the encoded form. Make sure you copy the **Decoded** view, which starts with `apiVersion: v1`.

**From the Project claim (organisation administrators):** the same kubeconfig is published, base64-encoded, in the project's status. With your organisation kubeconfig:

```bash
kubectl get project <project-name> \
  -o jsonpath='{.status.workspace.kubeconfigBase64}' | base64 -d > ~/.kube/<project-name>.yaml
```

---

## kubeconfig Structure

A project kubeconfig is a standard Kubernetes kubeconfig pointing at your project's API endpoint. A downloaded kubeconfig looks like this (values in `<...>` are specific to your organisation and project):

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: dev
    cluster:
      server: https://<platform-api-host>:443/clusters/root:cloud:<organisation>:<project>
      certificate-authority-data: <base64-encoded-CA>
users:
  - name: oidc
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://<organisation-login-host>/realms/<organisation>-realm
          - --oidc-client-id=platform-client
          - --oidc-client-secret=<included in your download>
        installHint: oidc-login is not installed. To learn more, please go to https://github.com/int128/kubelogin
        interactiveMode: IfAvailable
contexts:
  - name: dev
    context:
      cluster: dev
      user: oidc
current-context: dev
```

Things to note:

- The `server` URL is unique per project — every project in every organisation has its own endpoint, ending in `<organisation>:<project>`.
- The cluster, user and context names are the same in every downloaded kubeconfig: the context is always called `dev`. Tools that ask for a context name (for example Terraform's `config_context`) need `dev`, unless you rename it.
- The kubeconfig contains your organisation's login client settings, including a client secret. Treat the whole file as a credential (see [Security](#security)).

---

## Authentication Flow

Your kubeconfig uses OIDC for authentication:

1. `kubectl` calls the `oidc-login` exec plugin
1. `oidc-login` checks for a cached, valid token
1. If none, it opens a browser to your organisation's login page
1. You authenticate; the token is cached and reused until expiry

Token lifetime is configured by your organisation's authentication policy.

---

## Multiple Projects

Every downloaded kubeconfig uses the same cluster, user and context names (`dev`, `oidc`, `dev`). If you merge two of them with `kubectl config view --flatten`, the entries with the same name collide and one project's endpoint is lost.

Keep one file per project and choose the project with the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=~/.kube/proj-frontend.yaml
kubectl get virtualmachines

export KUBECONFIG=~/.kube/proj-backend.yaml
kubectl get virtualmachines
```

<!-- TODO(SA-8708): document a tested procedure for merging several project kubeconfigs (renaming cluster, user and context in each file first) -->

---

## Requesting a New kubeconfig

Get a fresh copy the same way as the first one: see [Where to Get Your kubeconfig](#where-to-get-your-kubeconfig). If you cannot see your project in the console, ask your organisation administrator to check that you are listed in the project's `access` entries by your email address.

---

## Security

- Store kubeconfig files securely — they grant API access to your project
- Do not commit kubeconfig files to version control
- If a kubeconfig is compromised, contact your administrator immediately to revoke access

---

## What's Next?

- [Setup kubectl](setup-kubectl.md) — Configure kubectl with your project kubeconfig
- [Terraform Access](../terraform-access/setup-terraform.md) — Use the same endpoint with Terraform
- [GitOps Access](../gitops-access/argocd-setup.md) — Register with ArgoCD or Flux
