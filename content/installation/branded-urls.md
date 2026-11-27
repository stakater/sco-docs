# Branded URLs

Give your users your own addresses for the SCO portal and its login page, for
example `portal.example.com` and `auth.example.com`, while the cluster's internal
addresses keep working. You turn it on in four steps, all in
`KubeStackConfig.spec.parameters.branding`, and you can stop after any step.

!!! note "Not tested yet"
    Points marked **Not tested yet** come from the platform's code and design, but
    have not been run end to end. Try them on a test cluster first.

## How it works

The branded and the internal addresses run in parallel. Nothing that uses the
internal addresses today breaks.

- **The login service answers on every hostname, each with its own issuer.**
  Setting `authHost` makes it take its hostname from each request. A login on
  `auth.example.com` gets tokens issued by `https://auth.example.com/realms/<realm>`,
  and a login on the internal hostname keeps the internal issuer.
- **Each service that checks logins uses one login hostname at a time.** The portal
  backend, each hosted cluster's OAuth server and the mesh each trust either the
  internal or the branded login hostname, and steps 2 to 4 move them one by one.
  This is not about browsing: users can open the portal on either hostname, even in
  two tabs at once, and log in once per tab.
- **No redirect between the two hostnames.** A token is bound to the hostname it was
  issued on. Redirecting the internal login page to the branded one fails with
  `invalid_token`, so move the services instead.
- **Inside your network, the branded login hostname must resolve to an internal
  address.** Anything that calls the login service from inside the platform (the
  portal backend, hosted clusters, mesh components) usually cannot reach your public
  entry point from inside. Steps 2 and 3 cover this.

## Before you start

1. **Platform version.** Your kubestack-config release must have all the branding
   fields. Check with `oc explain kubestackconfig.spec.parameters.branding`: you need
   `portalHost`, `authHost`, `authHostIssuer`, `hostedClusterAuth` and `authHostMesh`.
1. **Two hostnames** in a DNS zone you control, for example `portal.example.com` and
   `auth.example.com`.
1. **Public DNS records** for both, pointing at your public router's address. The
   platform creates them only when DNS is managed through AWS Route53: set
   `branding.zoneId` to your hosted zone. Otherwise create two A records yourself.
1. **Certificate.** There is no separate certificate to upload. The branded hostnames
   go onto the cluster's existing public router certificate (TLS Secret
   `cluster-certificate`). How depends on `KubeStackConfig.spec.parameters.certificate`:
    - `type: managed` (cert-manager with Route53 DNS-01): automatic. The platform adds
      both hostnames to the certificate. The DNS-01 credentials must be able to answer
      for your branded domain.
    - `type: byo` with `clusterIssuer`: the platform adds both hostnames to the
      certificate it requests from your `ClusterIssuer`. That issuer must be able to
      issue for your branded domain. Not tested yet.
    - `type: byo` without `clusterIssuer`: you own the certificate. Before step 1,
      reissue it with both branded hostnames added to `api.<base>`, `*.apps.<base>`
      and `*.public.<base>`, with its full chain, and install it as TLS Secret
      `cluster-certificate` in both `openshift-ingress` and `openshift-config`. Renewal
      stays with you. Not tested yet. See [Private Certificate Authority](private-ca.md).
1. **A notice to your users** for steps 2 to 4. Each step makes the affected users log
   in once more.
1. **In-cluster access to the login hostname.** From step 2 on, the portal backend
   fetches each organisation's signing keys from `https://auth.example.com` from
   inside the cluster. Firewalls, proxies or the network in front of your entry point
   must let that traffic through. If they block it, every portal login fails with
   401. Step 2 has the check.

## Step 1: branded hostnames

This step adds the branded hostnames. Nobody's login moves yet.

```yaml
spec:
  parameters:
    branding:
      portalHost: portal.example.com
      authHost: auth.example.com
      zoneId: <your Route53 zone ID>   # only with Route53
```

**What happens:**

- The portal and the login service are served on the new hostnames as well as the
  internal ones.
- The login service switches to taking its hostname from each request. It restarts,
  so plan a short login outage.
- On the branded login hostname, the administration console is reachable only from
  `100.64.0.0/10`, so administrators keep using the internal hostname.

**Before you apply:** remove any override of your own that pins a fixed login-service
`hostname`. Otherwise it keeps that fixed hostname and step 2 fails.

**Check afterwards:**

1. Both hostnames resolve publicly, and the router certificate lists them.
1. `https://auth.example.com/realms/<realm>/.well-known/openid-configuration` returns
   200, and its `issuer` is `https://auth.example.com/realms/<realm>`.
1. The same URL on the internal hostname still returns 200, with the internal issuer.
1. `https://portal.example.com` opens the portal.

**Back out:** remove the two hostnames. Do this only before step 2.

## Step 2: portal login

This step moves the portal login to the branded hostname. Run it only after step 1's
checks pass.

**Before you apply:** check that the login hostname answers from inside the cluster,
from the portal's namespace. Use any image with `curl`:

```bash
oc run auth-check -n <portal-namespace> --rm -i --restart=Never \
  --image=registry.access.redhat.com/ubi9/ubi-minimal -- \
  curl -s -o /dev/null -w '%{http_code}\n' \
  https://auth.example.com/realms/<realm>/.well-known/openid-configuration
```

Go on only when it returns **200**. A timeout or a certificate error here means portal
logins will fail with 401 after the switch. Fix the network path or trust first.

```yaml
    branding:
      authHostIssuer: true
```

**What happens:** every organisation's portal login and tokens move to
`https://auth.example.com`. The platform trusts both issuers during the move, so
nothing breaks halfway. Portal users log in once more. The login service does not
restart, and hosted-cluster logins do not change.

**Check afterwards:**

1. Log in to `https://portal.example.com`. The login page is on `auth.example.com`,
   and you land back on the portal with your projects loaded.
1. Calls to the portal API without a token still return 401, not 5xx.

**Back out:** set `authHostIssuer: false`. Users log in once more. Not tested yet.

## Step 3: hosted-cluster login

This step moves the console and `oc` login of hosted OpenShift clusters to the
branded hostname. **Get the DNS right first**, or the clusters' login breaks.

**Why DNS matters:** a hosted cluster's OAuth server checks the login service through
the cluster's own network and DNS. If `auth.example.com` resolves there to your public
address, the check fails and the cluster shows no login button.

**1. Make the branded login hostname resolve internally.**

- **Resolver record:** add `auth.example.com` → your internal router address on the
  resolver your hosted clusters forward to. With the platform's OpenBSD Unbound
  add-on, the platform adds this record itself once `authHost` is set.
- **DNS split on the hosted clusters:**
    - Public clusters: the platform adds `authHost` to the split zones when the split
      is enabled.
    - Private clusters: they need a split too. Add `auth.example.com` only, not your
      whole parent zone, which would also capture the hosting cluster's own service
      names. Set it in `openshiftInternalClusterConfig.hostedClusterConfig.dnsSplit`
      (`enabled: true`, `zones`, and `upstreams` = your resolvers) through an override
      for the `crossplane-package-openshift-cluster` addon, see
      [Platform Configuration](configuration.md).
    - A `zones` list set in an override replaces the default list, so restate every
      zone in it.

!!! warning
    The DNS split replaces the hosted cluster's whole DNS operator configuration
    (`dns.operator/default`). Check it first for forwarders someone set by hand, and
    keep them. Never remove the split once logins have moved: that deletes the
    configuration (expected from how the split is applied; not tested yet).

**2. Probe from every hosted cluster.** Run this from each cluster's OAuth server, in
its hosted control plane namespace on the hosting cluster:

```bash
oc exec -n <hosted-control-plane-namespace> deploy/oauth-openshift -c oauth-openshift -- \
  curl -s -o /dev/null -w '%{http_code}\n' \
  https://auth.example.com/realms/<realm>/.well-known/openid-configuration
```

Go on only when every cluster returns **200**.

**3. Switch.**

```yaml
    branding:
      hostedClusterAuth: true
```

**What happens:**

- Every hosted cluster without an OAuth override of its own moves its login to
  `auth.example.com`, and so does every cluster you create from now on (not tested
  yet for new clusters).
- No recreate is needed. The cluster's OAuth server restarts, and its users log in
  once more.
- Each cluster's own OAuth hostname does not change: it is fixed when the cluster is
  created.

**Check afterwards:**

1. Each `HostedCluster` shows `ValidIDPConfiguration` and `Available` True.
1. A real `oc login --web` to one public and one private cluster lands on
   `auth.example.com` and succeeds.

**Back out:** set `hostedClusterAuth: false`. Leave the DNS split in place.

## Step 4 (optional): mesh login

This step moves `netbird up` for every organisation's mesh to the branded login
hostname, so users log in on the same page as the portal. Tell your users first.

```yaml
    branding:
      authHostMesh: true
```

**What happens:** the switch is immediate for every organisation's mesh. Users
enrolled through single sign-on run `netbird up` once more, and mesh dashboard
sessions end. Peers enrolled with a setup key keep working. The mesh components must
resolve `auth.example.com` internally too, as in step 3.

**Check afterwards:** a user who is logged in to the portal runs `netbird up`, gets no
password prompt, and connects.

**Back out:** set `authHostMesh: false`. Not tested yet. Single sign-on users run
`netbird up` once more.

## Known pitfalls

- **A 401 on everything after step 2 usually means the cluster cannot reach the login
  hostname.** It is not a permissions problem (that would be 403). The portal backend
  could not fetch the signing keys from `auth.example.com`: the traffic is blocked on
  the way, the hostname resolves to an address it cannot reach, or the certificate is
  not trusted. Run the step 2 check again. New organisations also need their users'
  email addresses verified.
- **Routes without the public label get a 503.** The public router admits only Routes
  labelled `stakater.com/ingress-shard=public`. The platform labels its own, but a
  Route generated from an older Ingress keeps its old labels: delete it so it
  regenerates.
- **An old resolver chart pinned in an override drops the record silently.** If you
  pin the Unbound add-on's chart version in an override, check that the
  `auth.example.com` record exists before step 3.
- **Existing clusters keep their OAuth hostname.** The OAuth server's own address
  (shown briefly in login redirects and on the `oc` token page) is fixed at cluster
  creation. Only a recreated cluster gets a new one.
- **Check between steps.** Steps 2 to 4 each change something users notice. You can
  run them in separate windows or in one, but finish each step's checks before the
  next, and keep the internal addresses running throughout.

## What's Next?

- [Private Certificate Authority](private-ca.md) - Serve the platform with certificates from your own CA
- [Platform Configuration](configuration.md) - Override platform defaults per cluster
