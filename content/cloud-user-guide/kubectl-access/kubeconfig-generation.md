# kubeconfig Generation

This page explains the structure of your project kubeconfig and how authentication works against SCO project endpoints.

---

## kubeconfig Structure

A project kubeconfig is a standard Kubernetes kubeconfig pointing at your project's virtual API endpoint:

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: proj-frontend
    cluster:
      server: https://kcp.example.com/clusters/org-acme:proj-frontend
      certificate-authority-data: <base64-encoded-CA>
users:
  - name: alice
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://keycloak.example.com/realms/org-acme
          - --oidc-client-id=sco-cli
          - --oidc-extra-scope=groups
contexts:
  - name: proj-frontend
    context:
      cluster: proj-frontend
      user: alice
current-context: proj-frontend
```

The `server` URL is unique per project — every project in every organisation has its own endpoint.

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

Merge multiple project kubeconfig files into one:

```bash
KUBECONFIG=~/.kube/proj-frontend.yaml:~/.kube/proj-backend.yaml \
  kubectl config view --flatten > ~/.kube/config
```

Switch between them:

```bash
kubectl config use-context proj-frontend
kubectl config use-context proj-backend
```

---

## Requesting a New kubeconfig

kubeconfig files are available from the SCO console under your project's **Settings → Access → Download kubeconfig**. If your kubeconfig has been revoked, contact your administrator to generate a new one.

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
