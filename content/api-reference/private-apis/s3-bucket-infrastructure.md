# S3 Bucket (Infrastructure)

Low-level infrastructure API for provisioning an S3-compatible bucket via NooBaa (ODF) with explicit control over the ObjectBucketClaim namespace, provider config, and optional public route exposure.

!!! note
    This is a private infrastructure API intended for platform engineers. Cloud users should use the [S3 Bucket](../public-apis/s3-bucket.md) public API instead.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `infrastructure.stakater.com` |
| **Version** | `v1` |
| **Kind** | `XS3Bucket` |
| **Scope** | Cluster-scoped |
| **Claim Kind** | `S3Bucket` |

## Spec Parameters

All parameters are nested under `spec.parameters`.

### Required

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `namespace` | `string` | `openshift-storage` | Namespace where the ObjectBucketClaim will be created. Must exist and be writable by NooBaa. |

### Optional

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `kubernetesProviderConfigName` | `string` | `kubernetes-provider` | Name of the Kubernetes provider config to use for creating the ObjectBucketClaim and reading back the OBC-generated Secret. |
| `publicRouteName` | `string` | `""` | Name of an additional NooBaa S3 Route exposing the bucket via a publicly-routable ingress shard (e.g. `s3-public`, created by the `odf-instance` chart). When set, the composition observes that Route and surfaces its externally-reachable host in `status.bucket.endpoint`. Leave empty on clusters where NooBaa's default internal Route is the only S3 endpoint. |

### Top-level fields

| Field | Type | Description |
|-------|------|-------------|
| `managementPolicies` | `string[]` | Crossplane management policy. Defaults to `["*"]`. |
| `providerConfigRef.name` | `string` | Reference to an AWS ProviderConfig (used for NooBaa's S3 API). |

## Status Fields

`status.bucket` carries non-sensitive bucket metadata only. Credentials live in the OBC-generated `<claim-name>` Secret in the target namespace; they are surfaced to cloud-tier consumers via api-syncagent related resources on the cloud-tier `PublishedResource` — not here.

| Field | Type | Description |
|-------|------|-------------|
| `status.bucket.name` | `string` | Provisioned bucket name (as assigned by NooBaa) |
| `status.bucket.endpoint` | `string` | S3 endpoint hostname |

## Examples

### Minimal (private, internal endpoint only)

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: XS3Bucket
metadata:
  name: my-bucket
spec:
  parameters:
    namespace: openshift-storage
```

### With a public ingress route

```yaml
apiVersion: infrastructure.stakater.com/v1
kind: XS3Bucket
metadata:
  name: app-bucket
spec:
  parameters:
    namespace: openshift-storage
    publicRouteName: s3-public
```
