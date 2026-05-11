# Auto-Meme Generator 🚀

An event-driven, serverless web application that automatically generates creative memes from user-uploaded images. Built with AWS, Terraform, and a sleek Neobrutalist frontend.

## 🏗️ Architecture

This project is fully serverless and relies on an event-driven workflow to process images efficiently:

*   **Frontend**: A responsive Neobrutalist web interface. Served securely via **AWS CloudFront** with Origin Access Control (OAC) pointing to an **S3** bucket.
*   **API Layer**: **Amazon API Gateway** routes incoming requests from the frontend to the backend services.
*   **Orchestration**: **AWS Step Functions** orchestrates the meme generation pipeline to ensure reliability and scalability.
*   **Microservices (AWS Lambda)**:
    *   `upload`: Generates pre-signed S3 URLs so the frontend can upload images securely and directly to S3.
    *   `analyze`: Analyzes the uploaded image content.
    *   `caption`: Generates a contextual, funny caption for the image.
    *   `compose`: Uses image processing (Sharp) and custom fonts to stitch the text onto the image.
    *   `status`: Allows the frontend to poll for the completed meme URL.
*   **Data & Storage**: **Amazon DynamoDB** tracks job states, while **Amazon S3** stores the original and processed meme images.

## 📋 Prerequisites

Before deploying this project yourself, ensure you have the following installed:
1.  [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (Configured with `aws configure`)
2.  [Terraform](https://developer.hashicorp.com/terraform/downloads)
3.  [Node.js](https://nodejs.org/en) (for any local lambda packaging/testing)

## 🚀 Deployment Guide

### 1. Provision Infrastructure
Navigate to the `terraform` directory to initialize and deploy the AWS infrastructure.

```bash
cd terraform
terraform init
terraform plan
terraform apply
```
*Note: Make sure to review the planned resources before typing `yes`. Terraform will provision all AWS resources and automatically sync your frontend code to the S3 bucket.*

### 2. Configure the Frontend
1. Open `src/frontend/index.html`.
2. Locate the API endpoint variable (e.g., `const API_URL = '...'`) and replace it with the **API Gateway URL** from your Terraform outputs.

### 3. Access the Application
CloudFront distributions can take a few minutes to fully deploy. Once the status shows as `Deployed` in the AWS Console, you can visit the **CloudFront URL** provided in the Terraform outputs to view and use your Auto-Meme Generator!

### 4. Teardown & Cleanup
To avoid incurring unwanted AWS charges, you can cleanly destroy all resources when you are done testing:

```bash
cd terraform
terraform destroy
```
*Note: We have configured `force_destroy = true` on the S3 buckets, meaning Terraform will automatically empty and delete the buckets without requiring manual intervention.*

## 🛡️ Security

*   The frontend S3 bucket blocks all public access and is exclusively accessible via CloudFront (OAC).
*   S3 pre-signed URLs ensure that image uploads are temporary, secure, and direct.
*   Ensure `.tfstate` files and any local `.env` files are ignored via `.gitignore` to prevent secret leakage.
