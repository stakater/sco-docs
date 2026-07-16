# How to Create an S3 Bucket

Learn how to provision an S3-compatible object storage bucket in your project.

Emma, a developer at ACME Corp, needs persistent object storage for her application's file uploads. She can provision an S3 bucket and consume it from a workload in minutes, using any AWS SDK or S3 client.

## Prerequisites

- A [Project](create-project.md) already created
- The `s3bucket.storage.cloud.stakater.com` API available
- `kubectl` configured with your project kubeconfig
- To read the credentials: access to your organisation's [Vault](create-vault.md) from a device enrolled on the [Mesh](create-mesh.md)

## What Gets Created

When you create an S3Bucket claim, the platform provisions:

- An **S3-compatible bucket** in the platform's object storage
- **Credentials in your organisation's vault**, at the path published in the claim's status

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

Inspect the endpoint, bucket name and credentials location:

```bash
kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket}'
```

```json
{"name":"my-bucket-0c1a2b3c","endpoint":"s3.apps.example.stakater.cloud","credentialsRef":{"vault":"https://bao.acme.mesh.example.stakater.cloud","mount":"services","path":"my-project/s3bucket/my-bucket"}}
```

## Step 4: Read the Credentials

The platform stores the credentials in your organisation's vault at `status.bucket.credentialsRef`. Open the vault URL in a browser (from a Mesh-enrolled device) and navigate to the `services` secret engine, or use the CLI:

```bash
export BAO_ADDR=$(kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket.credentialsRef.vault}')
bao login -method=oidc
bao kv get -mount=services $(kubectl get s3bucket my-bucket -o jsonpath='{.status.bucket.credentialsRef.path}')
```

Keys match the AWS SDK / CLI environment variable convention:

| Key | Description |
|-----|-------------|
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |
| `BUCKET_NAME` | Bucket name (same as `status.bucket.name`) |
| `BUCKET_HOST` | S3 endpoint host (same as `status.bucket.endpoint`) |
| `BUCKET_PORT` | S3 endpoint port |

### Mount the credentials into a workload

Create a Secret next to your workload from the vault values, then reference it with `envFrom` so every key becomes an environment variable:

```bash
bao kv get -mount=services -format=json my-project/s3bucket/my-bucket \
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

### Test from your workstation

Export the credentials from the vault and use the AWS CLI with the bucket's endpoint:

```bash
CREDS=$(bao kv get -mount=services -format=json my-project/s3bucket/my-bucket | jq -r '.data.data')
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.AWS_ACCESS_KEY_ID')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.AWS_SECRET_ACCESS_KEY')
export BUCKET_HOST=$(echo "$CREDS" | jq -r '.BUCKET_HOST')
export BUCKET_NAME=$(echo "$CREDS" | jq -r '.BUCKET_NAME')

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

The platform tears down the bucket and removes the credentials from your organisation's vault. If you copied the credentials into Secrets next to your workloads, remember to delete those too:

```bash
kubectl delete secret my-bucket
```

!!! warning
    Bucket contents are deleted when the claim is removed. Export or migrate any data you need to keep before deletion.

## What's Next?

- [Create a Postgres Database](create-postgres.md) - Provision a PostgreSQL database alongside your bucket
- [Provision a Virtual Machine](provision-virtual-machine.md) - Run compute that consumes the bucket
- [Deploy Your First App](deploy-first-app.md) - Wire the bucket into an application deployment
