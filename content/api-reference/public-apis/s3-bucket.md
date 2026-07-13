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

`status.bucket` carries non-sensitive bucket metadata only. Access credentials are **not** placed here — they are delivered to the project as a Secret (see [Credentials](#credentials)).

| Field | Type | Description |
|-------|------|-------------|
| `status.bucket.name` | `string` | Provisioned bucket name |
| `status.bucket.endpoint` | `string` | S3 endpoint hostname to target with an S3 client |

## Credentials

When the bucket is ready, the platform delivers a Secret named after the claim (`<metadata.name>`) into the project. It contains the keys expected by the AWS SDK / CLI:

| Secret key | Description |
|------------|-------------|
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

### Consuming the credentials

Mount the delivered Secret as environment variables on a workload:

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

- Platform-tier API: [S3 Bucket (Infrastructure)](../private-apis/s3-bucket-infrastructure.md)
