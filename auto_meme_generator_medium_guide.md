# Build a Serverless Auto Meme Generator on AWS with Terraform and Gemini AI

> **Drop a photo into a Neobrutalist Web App → get a fully composed meme back in seconds — zero servers, zero babysitting.**

---

## 🔥 New Features Added

This project has been recently upgraded with the following production-ready features:
1. **Neobrutalist UI Design:** A visually stunning, responsive SPA featuring bold borders, vibrant colors, drop-shadows, and micro-animations for an engaging user experience.
2. **Secure CloudFront/OAC Infrastructure:** The frontend S3 bucket is now entirely private. It is exposed securely only through a CloudFront Distribution utilizing Origin Access Control (OAC), ensuring best-practice security.
3. **End-to-End Event-Driven Architecture:** The backend seamlessly choreographs the pipeline using EventBridge, Step Functions, S3 Events, and DynamoDB.

---

## What You'll Build

An end-to-end, fully serverless Fullstack Web App on AWS that:

1. **Hosts** a Neobrutalist Single-Page Application (SPA) securely behind **Amazon CloudFront** using Origin Access Control (OAC).
2. **Generates** presigned URLs via an **API Gateway** so the browser can upload images directly to S3.
3. **Detects** what's in the uploaded photo using **Amazon Rekognition**.
4. **Writes** a witty, sarcastic, two-line meme caption (top/bottom text) using **Google Gemini AI**.
5. **Renders** the caption onto the image using the **Sharp** image library.
6. **Stores** the finished meme and its state in **DynamoDB**, allowing the frontend to poll for completion.

The entire backend workflow is event-driven and orchestrated by **AWS Step Functions**. The frontend is a clean, dependency-free HTML/JS app. The whole thing is provisioned with a single `terraform apply`.

### Architecture Overview

```
[Browser]
    │ 1. Request presigned URL 
    ├─► API Gateway ─► Lambda: Meme_0_Upload (Creates DynamoDB PENDING record)
    │
    │ 2. PUT Image directly
    ├─► S3 (Input Bucket) ───┐
    │                        │ 3. Object Created Event
    │ 4. Poll status         ▼
    ├─► API Gateway      EventBridge Rule
    │                        │ 5. Start Execution
    ▼                        ▼
[CloudFront]          Step Functions State Machine
    │                   ├─► Lambda: Meme_1_Analyze (Rekognition)
    │ (OAC)             ├─► Lambda: Meme_2_Caption (Gemini 2.5 Flash)
    ▼                   └─► Lambda: Meme_3_Compose (Sharp SVG overlay)
[S3 Frontend Bucket]              │
                                  ├─► S3 (Output Bucket)
                                  └─► DynamoDB (UpdateItem to COMPLETED)
```

---

## Prerequisites

Before you start, make sure you have the following ready:

| Requirement | Notes |
|---|---|
| AWS Account | With an IAM user/role that has broad admin permissions |
| AWS CLI | Installed and configured (`aws configure`) |
| Terraform | v1.5 or later |
| Node.js | v20 LTS (for building the Sharp Lambda Layer & npm dependencies) |
| Google Gemini API Key | Free tier works — get one at [aistudio.google.com](https://aistudio.google.com) |

---

## Step 1: Set Up Your Project Structure

Create the following folder layout to keep things organized:

```
auto-meme-generator/
├── layer/
│   └── nodejs/
│       └── package.json       ← Sharp dependency for the Lambda layer
├── src/
│   ├── analyze/index.mjs      ← Step 1: Rekognition
│   ├── caption/index.mjs      ← Step 2: Gemini AI (Top/Bottom text)
│   ├── compose/               ← Step 3: Sharp image composer
│   │   ├── index.mjs          
│   │   └── fonts/Anton.ttf    ← Embedded meme font
│   ├── status/index.mjs       ← Polling API Endpoint
│   ├── upload/index.mjs       ← Presigned URL API Endpoint
│   └── frontend/index.html    ← The Neobrutalist Web UI
└── terraform/
    ├── main.tf                ← S3, DynamoDB, Secrets
    ├── lambda.tf              ← Lambda Provisioning
    ├── iam.tf                 ← Least-Privilege Roles
    ├── sfn.tf                 ← Step Functions
    ├── events.tf              ← EventBridge
    ├── api.tf                 ← API Gateway v2 routes
    ├── cloudfront.tf          ← OAC & CloudFront Distribution
    └── outputs.tf             ← Deployment URLs
```

---

## Step 2: Build the Sharp Lambda Layer

Sharp is a native Node.js image-processing library. Because it contains compiled C++ binaries, it **must** be built targeting the Linux environment that Lambda runs on.

### 2a. Create the Layer's `package.json`

In `layer/nodejs/package.json`:

```json
{
  "name": "nodejs",
  "version": "1.0.0",
  "dependencies": {
    "sharp": "^0.34.5"
  }
}
```

### 2b. Install for the `linux/x64` Platform

From the `layer/nodejs/` directory, run:

```bash
npm install --platform=linux --arch=x64 --libc=glibc
```

### 2c. Zip the Layer

Navigate back to the `terraform/` directory and run:

```bash
cd ../layer
zip -r ../terraform/sharp_layer.zip nodejs/
```

---

## Step 3: The API Lambdas (Upload & Status)

Before starting the Step Functions pipeline, we need API endpoints.

**`src/upload/index.mjs`**: Generates a UUID `memeId`, a presigned S3 PUT URL for the browser, and writes a `PENDING` record to DynamoDB.
*(Requires `@aws-sdk/s3-request-presigner`)*

**`src/status/index.mjs`**: Polled by the frontend. Reads the `memeId` from DynamoDB. If `COMPLETED`, it returns a presigned GET URL for the output bucket.
*(Requires `@aws-sdk/s3-request-presigner`)*

---

## Step 4: The Step Functions Pipeline

### Lambda 1 — Analyze (`src/analyze/index.mjs`)
Triggered via EventBridge when S3 receives the image. Extracts the `memeId` from the S3 key (`uploads/{memeId}.jpg`), uses Amazon Rekognition to extract labels, and passes them forward.

### Lambda 2 — Caption (`src/caption/index.mjs`)
Takes the labels, securely fetches the Gemini API key from AWS Secrets Manager, and asks Gemini to return a pipe-delimited string (e.g., `WHEN YOU SEE IT|YOUR BRAIN EXPLODES`). Returns `topText` and `bottomText`.

### Lambda 3 — Compose (`src/compose/index.mjs`)
The heavy lifter. Downloads the image, loads `Anton.ttf` natively via base64, and uses Sharp to render two distinct SVGs onto the image (`gravity: north` and `gravity: south`). Finally, uploads the meme to the output bucket and calls `UpdateItem` on DynamoDB to set the status to `COMPLETED`.

---

## Step 5: Secure CloudFront Hosting

To host the SPA securely:
1. An S3 bucket (`meme-frontend-*`) is created, but **Public Access is Blocked**.
2. A CloudFront Distribution is deployed in front of the bucket.
3. An **Origin Access Control (OAC)** is attached to CloudFront.
4. The S3 bucket policy strictly permits `s3:GetObject` only if `AWS:SourceArn` matches the CloudFront distribution ARN.

This guarantees your site is served over HTTPS and the bucket cannot be accessed directly.

---

## Step 6: Deploy with Terraform

Once all your code is in place:

1. Install API dependencies:
   ```bash
   cd src/upload && npm install
   cd ../status && npm install
   ```
2. Deploy the infrastructure:
   ```bash
   cd ../../terraform
   terraform init
   terraform apply -auto-approve
   ```
3. Look at the Terraform outputs. Copy the `api_endpoint` and paste it into `API_BASE_URL` at the bottom of your `src/frontend/index.html` file.
4. Upload your frontend code to the S3 bucket:
   ```bash
   aws s3 cp ../src/frontend/index.html s3://<your-frontend-bucket>/index.html
   aws cloudfront create-invalidation --distribution-id <your-cf-id> --paths "/*"
   ```

### 🚨 Critical Last Step: Set Your API Key!
Terraform created an AWS Secret named `auto-meme/gemini-key-...` with a dummy value. You **must** go to the AWS Secrets Manager Console and replace `REPLACE_ME_IN_AWS_CONSOLE` with your real Gemini API key.

---

## Conclusion

You now have a production-ready, fully serverless web application! You've successfully integrated presigned S3 uploads, Step Functions orchestration, AI integration via Secrets Manager, advanced image compositing, and secure CloudFront hosting. 

And best of all — you only pay for exactly what you use. Happy Meme Generating!
