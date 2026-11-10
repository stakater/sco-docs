# Private Certificate Authority

Install SCO on a domain whose certificates come from your own certificate
authority (CA): for example an internal PKI that your users and systems trust,
but the public internet does not.

Decide this **before** installing. Private-CA mode cannot be turned on later.

## Choose how certificates reach the platform

The platform needs certificates for its routers and its API server. With a
private CA they reach it in one of two ways:

| | A `ClusterIssuer` | Certificate files |
|---|---|---|
| How it works | cert-manager requests every certificate from your CA through a `ClusterIssuer` you provide | You install one certificate for the cluster, and the platform serves it |
| Renewal | Automatic | You replace the certificate yourself |
| Hosted OpenShift clusters | Use the same issuer | Need an issuer of their own, see [Hosted clusters](#hosted-clusters) |
| Platform mesh | Available | Stays off |
| Choose it when | Your CA offers ACME, or can give you a sub-CA for your domain | Your CA only hands out certificates |

Both ways need the same three settings:

- `certificate.type: byo` and `certificate.privateCA: true` in the `KubeStackConfig` claim
- your root CA certificate, passed to `ksp up` with `--trusted-ca`

## Trust your CA

Pass the root certificate of your CA to `ksp up`:

```bash
ksp up ... --trusted-ca root-ca.pem
```

- The file holds one or more root certificates in PEM format. It must not hold a private key.
- `ksp up` adds them to the cluster's trusted CA bundle. The nodes pick up the bundle without rebooting.

## Option 1: a `ClusterIssuer`

1. Create a cert-manager `ClusterIssuer` backed by your CA, before installing. Either:
    - a CA issuer that signs with a **sub-CA** your CA issued for your domain. Ask for one limited to your domain (name constraints), so it cannot sign anything else.
    - an ACME issuer, if your CA offers ACME. The platform's certificates are wildcards, so the issuer must use a **DNS-01** solver. HTTP-01 does not work.
1. Name it in the claim:

    ```yaml
    certificate:
      type: byo
      privateCA: true
      clusterIssuer: <cluster-issuer>
    dns:
      type: byo
    ```

The platform then requests and renews all of its certificates through that issuer.

## Option 2: certificate files

!!! note "Needs a recent `ksp`"
    Certificate files need a `ksp` release that supports them. Check the
    [KubeStack+ CLI](prerequisites.md#kubestack-cli-ksp) table, or ask Stakater.

### The certificate

Ask your CA for **one** certificate with these names. `<base>` is the cluster
domain without its `apps.` prefix: for `apps.cluster.example.com` it is
`cluster.example.com`.

| Name | Served by |
|---|---|
| `api.<base>` | the API server |
| `*.apps.<base>` | the default router: the OpenShift console and platform routes |
| `*.public.<base>` | the platform's second router: the sign-in pages and the SCO console |

Add any branded host names you use.

!!! warning "A wildcard covers one level only"
    `*.cluster.example.com` covers `console.cluster.example.com`, but **not**
    `console.apps.cluster.example.com`. A single wildcard on `<base>` is not
    enough: the certificate needs `*.apps.<base>` and `*.public.<base>` by name.

`*.public` does not mean the router faces the internet. It is the platform's
second router, and it needs its own `LoadBalancer` address. On `scobasic`, that
address comes from your load balancer.

You need the certificate **with its full chain** (the certificate, then any
intermediate CA certificates, without the root) and its private key.

### Install it before `ksp up`

Create the Secret `cluster-certificate` in **both** namespaces:

```bash
for ns in openshift-ingress openshift-config; do
  oc create secret tls cluster-certificate \
    --cert=full-chain.pem --key=key.pem -n "$ns" \
    --dry-run=client -o yaml | oc apply -f -
done
```

### The claim

Leave out `clusterIssuer`:

```yaml
certificate:
  type: byo
  privateCA: true      # no clusterIssuer: the certificate comes from the Secrets
dns:
  type: byo
```

### What `ksp up` checks

Before it applies the claims, `ksp up` checks both Secrets:

- they exist, are TLS Secrets and hold a key
- the certificate covers the names above: `*.apps` and `*.public` in `openshift-ingress`, `api` in `openshift-config`
- it chains to a root you passed with `--trusted-ca`
- it has not expired. It warns when it expires within 30 days.

If a check fails, `ksp up` stops and prints the command to create the Secrets.

### Renew the certificate

Before the certificate expires, get a new one from your CA and run the same
command again for both namespaces. The routers and the API server load it within
a minute, without restarting.

The platform does not remind you. Track the expiry date yourself.

### Limits

- You renew the certificate by hand.
- The platform mesh stays off. It needs an issuer.
- Hosted OpenShift clusters need an issuer, see [Hosted clusters](#hosted-clusters).

## Hosted clusters

Every hosted OpenShift cluster gets its own wildcard certificate,
`*.apps.<cluster>.<base>`, when a user creates it. That needs an issuer.

- With **Option 1**, hosted clusters use your `ClusterIssuer`.
- With **Option 2**, name an issuer for hosted clusters in the `KubeStackConfig` claim. It can be an ACME issuer (DNS-01) or a CA issuer with a sub-CA limited to your domain:

    ```yaml
    openshiftCluster:
      internal:
        baseDomain: <base>
        certificate:
          clusterIssuer: <hosted-cluster-issuer>
    ```

Without it, hosted-cluster certificates are never issued.

## DNS records

With `dns.type: byo` you create the records yourself:

| Record | Points to |
|---|---|
| `api.<base>` | the API address of the cluster |
| `*.apps.<base>` | the ingress address of the cluster |
| `*.public.<base>` | the `LoadBalancer` address of the second router |

Find the second router's address with:

```bash
oc get svc -n openshift-ingress | grep LoadBalancer
```

Each hosted cluster needs two more records, `api.<cluster>.<base>` and
`*.apps.<cluster>.<base>`. The platform lists them, with their addresses, in
`status.dns` of the cluster's infrastructure resource on the management cluster.
A platform administrator reads them there; the project user's view of the cluster
does not show them:

```bash
oc get openshiftclusters.infrastructure.stakater.com -A \
  -o custom-columns=CLUSTER:.metadata.name,RECORDS:.status.dns.records
```

!!! tip "Put records where the name is served"
    - If `<base>` is a delegated zone, create the records **in that zone**. Records in its parent zone are ignored.
    - Many DNS consoles add the zone name for you. There, enter only the prefix, such as `api.mycluster`, not the full name.

## Clients

Clients that talk to the cluster must trust your root CA:

- **`oc`**: `oc login https://api.<base>:6443 --certificate-authority=root-ca.pem`, or add the root to your operating system's trust store.
- **Browsers**: import the root as a trusted certificate authority.

## What's Next?

- [`scobasic` Installation](scobasic.md)
- [OpenShift Installation](openshift.md)
