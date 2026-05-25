# How to Create an S3 Bucket

Learn how to provision an S3-compatible object storage bucket in your project.

Emma, a developer at ACME Corp, needs persistent object storage for her application's file uploads. She can provision an S3 bucket and consume it from a workload in minutes, using any AWS SDK or S3 client.

## Prerequisites

- A [Project](create-project.md) already created
- The `s3bucket.storage.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig

## What Gets Created

When you create an S3Bucket claim, the platform provisions:

- An **S3-compatible bucket** in the platform's object storage
- A **Secret** in your project containing access credentials and endpoint metadata, named after the claim

## Step 1: Define an S3Bucket Claim

Create a file named `bucket.yaml`:

```yaml
apiVersion: storage.cloud.stakater.com/v1
kind: S3Bucket
metadata:
  name: my-bucket
spec:
  parameters: {}
```

`spec.parameters` is empty — sizing and backend configuration are handled by the platform. The claim itself has no user-tunable fields.

## Step 2: Apply the Claim

```bash
kubectl apply -f bucket.yaml
```

## Step 3: Verify the Bucket

Check the claim status:

```bash
kubectl get s3bucket my-bucket
```

Wait for it to become ready:

```text
NAME        SYNCED   READY   AGE
my-bucket   True     True    1m
```

Inspect the endpoint and bucket name:

```bash
kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket}'
```

```json
{"name":"my-bucket-0c1a2b3c","endpoint":"s3.apps.example.stakater.cloud"}
```

## Step 4: Consume the Credentials

The platform delivers a Secret named after the claim (`my-bucket`) into your project. Its keys match the AWS SDK / CLI environment variable convention:

| Secret key | Description |
|------------|-------------|
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |
| `BUCKET_NAME` | Bucket name (same as `status.bucket.name`) |
| `BUCKET_HOST` | S3 endpoint host (same as `status.bucket.endpoint`) |
| `BUCKET_PORT` | S3 endpoint port |

### Inspect the Secret

```bash
kubectl get secret my-bucket -o jsonpath='{.data.BUCKET_NAME}' | base64 -d
```

### Mount it into a workload

Reference the Secret with `envFrom` so every key becomes an environment variable:

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

### Test from your workstation

Export the credentials and use the AWS CLI with the bucket's endpoint:

```bash
export AWS_ACCESS_KEY_ID=$(kubectl get secret my-bucket -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret my-bucket -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
export BUCKET_HOST=$(kubectl get secret my-bucket -o jsonpath='{.data.BUCKET_HOST}' | base64 -d)
export BUCKET_NAME=$(kubectl get secret my-bucket -o jsonpath='{.data.BUCKET_NAME}' | base64 -d)

aws --endpoint-url https://$BUCKET_HOST s3 ls s3://$BUCKET_NAME/
echo "hello" > hello.txt
aws --endpoint-url https://$BUCKET_HOST s3 cp hello.txt s3://$BUCKET_NAME/
aws --endpoint-url https://$BUCKET_HOST s3 ls s3://$BUCKET_NAME/
```

## Step 5: Delete the Bucket

When you no longer need the bucket, delete the claim:

```bash
kubectl delete s3bucket my-bucket
```

The platform tears down the bucket. The credentials Secret is removed from your project on a best-effort basis — if a stale `<claim-name>` Secret remains after the claim is gone, drop it with:

```bash
kubectl delete secret my-bucket
```

!!! warning
    Bucket contents are deleted when the claim is removed. Export or migrate any data you need to keep before deletion.

## What's Next?

- [Create a Postgres Database](create-postgres.md) - Provision a PostgreSQL database alongside your bucket
- [Provision a Virtual Machine](provision-virtual-machine.md) - Run compute that consumes the bucket
- [Deploy Your First App](deploy-first-app.md) - Wire the bucket into an application deployment
