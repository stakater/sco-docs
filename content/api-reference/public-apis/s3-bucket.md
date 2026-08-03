# S3 Bucket

Provisions an S3-compatible object storage bucket.

## API Details

| Field | Value |
|-------|-------|
| **API Group** | `storage.cloud.stakater.com` |
| **Version** | `v1` |
| **Kind** | `S3Bucket` |
| **Scope** | Namespace-scoped |

## Spec Parameters

`spec.parameters` is currently empty — sizing and backend configuration are handled by the platform. The claim itself carries no user-tunable fields.

## Status Fields

`status.bucket` carries non-sensitive bucket metadata plus a pointer to the credentials. Access credentials are **not** placed here — they are stored in your organisation's Vault (see [Credentials](#credentials)).

| Field | Type | Description |
|-------|------|-------------|
| `status.bucket.name` | `string` | Provisioned bucket name |
| `status.bucket.endpoint` | `string` | S3 endpoint hostname to target with an S3 client |
| `status.bucket.credentialsRef.vault` | `string` | URL of the Vault holding the credentials, reachable over your organisation's [Mesh](./mesh.md) |
| `status.bucket.credentialsRef.mount` | `string` | Secret engine the credentials are under (`services`) |
| `status.bucket.credentialsRef.path` | `string` | Path of the credentials within the mount (`<project>/s3bucket/<claim-name>`) |

## Credentials

When the bucket is ready, the platform writes the credentials into your organisation's [Vault](./vault.md) at the location given by `status.bucket.credentialsRef`. Read them in the Vault web UI, or with the CLI from a device enrolled on your organisation's Mesh:

```bash
export BAO_ADDR=$(kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket.credentialsRef.vault}')
bao login -method=oidc
bao kv get -mount=services $(kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket.credentialsRef.path}')
```

The keys match the AWS SDK / CLI convention:

| Key | Description |
|-----|-------------|
| `AWS_ACCESS_KEY_ID` | Access key for the bucket |
| `AWS_SECRET_ACCESS_KEY` | Secret key for the bucket |
| `BUCKET_NAME` | Same value as `status.bucket.name`, provided for convenience |
| `BUCKET_HOST` | Same value as `status.bucket.endpoint` |
| `BUCKET_PORT` | S3 endpoint port |

## Examples

### Minimal

```yaml
apiVersion: storage.cloud.stakater.com/v1
kind: S3Bucket
metadata:
  name: my-bucket
spec:
  parameters: {}
```

### Consuming the credentials from a workload

Fetch the credentials from the Vault and create a Secret next to your workload, then mount it as environment variables:

```bash
bao kv get -mount=services -format=json <project>/s3bucket/my-bucket \
  | jq -r '.data.data' > creds.json
kubectl create secret generic my-bucket --from-env-file=<(jq -r 'to_entries[] | "\(.key)=\(.value)"' creds.json)
rm creds.json
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: s3-client
  template:
    metadata:
      labels:
        app: s3-client
    spec:
      containers:
        - name: aws-cli
          image: amazon/aws-cli:latest
          command: ["sleep", "infinity"]
          envFrom:
            - secretRef:
                name: my-bucket
          env:
            - name: AWS_ENDPOINT_URL
              value: https://$(BUCKET_HOST)
```

## How-to Guide

[Create an S3 Bucket](../../how-to-guides/user/create-s3-bucket.md)

## Related

- [Vault](./vault.md) — where your bucket credentials live
- Platform-tier API: [S3 Bucket (Infrastructure)](../private-apis/s3-bucket-infrastructure.md)
