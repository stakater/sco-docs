# Logging In

Access to SCO is scoped per organisation. Each organisation has its own authentication realm and console URL — your credentials for one organisation cannot be used to access another.

---

## Step 1: Get Your Console URL

Your platform administrator will provide your organisation's console URL. It typically looks like:

```text
https://console.example.com/org/acme-corp
```

Or you may receive a direct login URL in a welcome email when your account is first created.

---

## Step 2: Log In

Navigate to your console URL in a browser. You will be presented with the login page for your organisation.

### Standard login

Enter your **email address** and the password provided by your administrator. Your email address is your login name; a separate username from your account details does not work here.

If your administrator created your account, the initial password is temporary: you are asked to set a new one, see [Step 3](#step-3-set-your-password-first-login).

### Company identity provider

If your organisation has connected its company identity provider, such as `Okta` or Microsoft `Entra` ID, the login page asks for your email address first:

- If your email domain belongs to the company identity provider, you go straight to its sign-in page. Sign in there with your company account.
- Otherwise, you see the password field. Enter the password provided by your administrator or set during account creation.

If your administrator has turned off the automatic redirect, the login page shows a button for the company identity provider instead. See [How to Connect Your Company Identity Provider](../../how-to-guides/user/connect-identity-provider.md).

!!! note
    If you had a password before your organisation connected its company identity provider, you keep signing in with that password until your administrator moves your account.

---

## Step 3: Set Your Password (First Login)

If this is your first login with credentials provided by an administrator, you will be prompted to set a new password. Choose a strong password and confirm it.

---

## After Login

After logging in, you will see the projects you have access to. Select a project to enter it, or configure `kubectl` using your project's kubeconfig for command-line access.

See [Setup kubectl](../kubectl-access/setup-kubectl.md) for CLI access.

The same account signs you in to every surface your organisation reaches — the Mesh dashboard, device enrolment, Vault, and cluster consoles. See [One Identity Across Your Organisation](organisation-identity.md).

---

## Logging Out

To log out, use the account menu in the top-right corner of the console and select **Sign out**.

---

## Troubleshooting

**"Invalid username or password":** Make sure you entered your email address, not a username, and check your password — passwords are case-sensitive. Use the **Forgot password** link if available, or contact your administrator.

**Redirected to the wrong realm:** Ensure you are using the console URL specific to your organisation.

**Account locked:** After multiple failed attempts, accounts may be temporarily locked. Contact your organisation administrator to unlock it.

---

## What's Next?

- [Accessing the Console](../../console/accessing-the-console.md) — Sign in to the console step by step
- [Managing Users](managing-users.md) — Invite colleagues and manage access
- [Creating Projects](../projects/creating-projects.md) — Set up your first project
- [Setup kubectl](../kubectl-access/setup-kubectl.md) — Configure CLI access
