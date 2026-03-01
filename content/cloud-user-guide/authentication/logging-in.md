# Logging In

Access to SCO is scoped per organisation. Each organisation has its own authentication realm and console URL — your credentials for one organisation cannot be used to access another.

---

## Step 1: Get Your Console URL

Your platform administrator will provide your organisation's console URL. It typically looks like:

```
https://console.example.com/org/acme-corp
```

Or you may receive a direct login URL in a welcome email when your account is first created.

---

## Step 2: Log In

Navigate to your console URL in a browser. You will be presented with the login page for your organisation.

### Standard login

Enter the username and password provided by your administrator or set during account creation.

### Single Sign-On (SSO)

If your organisation has configured SSO (Azure AD, Google, Okta, LDAP, or another corporate provider), a **Sign in with [Provider]** button will appear. Click it and complete authentication with your corporate credentials.

!!! note
    If SSO is configured, your organisation administrator may require you to use SSO exclusively. Contact your administrator if you are unsure which login method to use.

---

## Step 3: Set Your Password (First Login)

If this is your first login with credentials provided by an administrator, you will be prompted to set a new password. Choose a strong password and confirm it.

---

## After Login

After logging in, you will see the projects you have access to. Select a project to enter it, or configure `kubectl` using your project's kubeconfig for command-line access.

See [Setup kubectl](../kubectl-access/setup-kubectl.md) for CLI access.

---

## Logging Out

To log out, use the account menu in the top-right corner of the console and select **Sign out**.

---

## Troubleshooting

**"Invalid credentials":** Double-check your username and password — passwords are case-sensitive. Use the **Forgot password** link if available, or contact your administrator.

**Redirected to the wrong realm:** Ensure you are using the console URL specific to your organisation.

**Account locked:** After multiple failed attempts, accounts may be temporarily locked. Contact your organisation administrator to unlock it.

---

## What's Next?

- [Managing Users](managing-users.md) — Invite colleagues and manage access
- [Creating Projects](../projects/creating-projects.md) — Set up your first project
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure CLI access
