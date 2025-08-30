# IaC Project: Web Application CDN & Static Content Distribution
## Table of Contents
1.  Overview
2.  Scenario & Requirements
3.  Technologies Used
4.  Assumptions
5.  Design Decisions & Rationale
6.  Access Control & Security Best Practices
7.  Deployment Steps
---
## 1. Overview
This project provides an Infrastructure as Code (IaC) solution for deploying a web application's static content infrastructure across **development**, **staging**, and **production** environments. The primary goal is to establish secure and scalable content distribution networks (CDNs) and object storage solutions using **Terraform** and **AWS** services (Amazon S3 and Amazon CloudFront). The design adheres to industry best practices for security, scalability, and code structure, emphasizing modularity and the principle of least privilege.
---
## 2. Scenario & Requirements
The web application requires distinct setups for static content distribution in three environments: dev, staging, and production. Each environment needs three dedicated storage buckets, with content accessible via specific CDN paths.
**Specific Configurations:**
* **Development Environment:**
    * `/auth` &rarr; `Storage_Bucket1_dev`
    * `/info` &rarr; `Storage_Bucket2_dev`
    * `/customers` &rarr; `Storage_Bucket3_dev`
* **Staging Environment:**
    * `/auth` &rarr; `Storage_Bucket1_staging`
    * `/info` &rarr; `Storage_Bucket2_staging`
    * `/customers` &rarr; `Storage_Bucket3_staging`
* **Production Environment:**
    * `/auth` &rarr; `Storage_Bucket1_prod`
    * `/info` &rarr; `Storage_Bucket2_prod`
    * `/customers` &rarr; `Storage_Bucket3_prod`
**Key Requirements:**
* **Secure Storage:** Each storage bucket must adhere to **versioning** and **server-side encryption** standards.
* **CDN Integration:** Implement IaC to establish CDN distributions, each directed towards its respective storage bucket and configured for the appropriate paths.
* **Access Policies:** Define customized **access policies and roles** for storage bucket and CDN access, upholding the **principle of least privilege**.
* **Modularity & Reusability:** Structure IaC code with **modules** and employ **variables/outputs** for effective parameterization.
---
## 3. Technologies Used
* **Cloud Provider:** AWS (Amazon Web Services)
    * **Object Storage:** Amazon S3 (Simple Storage Service)
    * **Content Delivery Network (CDN)::** Amazon CloudFront
    * **Key Management:** AWS KMS (Key Management Service)
* **Infrastructure as Code (IaC) Tool:** Terraform (HashiCorp)
    * **Language:** HashiCorp Configuration Language (HCL)
---
## 4. Assumptions
The following assumptions underpin the design and deployment of this IaC solution:
* **Terraform & AWS CLI Setup:** It is assumed that **Terraform is installed and configured**, and the **AWS CLI is set up** with the necessary credentials to interact with your AWS account.
* **AWS Region:** All resources will be deployed in the `us-east-1` AWS region, as is standard practice for CloudFront distribution certificates (ACM certificates must be in `us-east-1`).
* **Programmatic User Permissions:** A programmatic AWS IAM user (e.g., `beyondInco`) exists with **restricted permissions**:
    * Full access to S3 and CloudFront services.
    * Crucially, this user is **restricted to managing resources tagged with `project = "beyondinco"`**. This enforces a strong least privilege model.
* **Existing ACM Certificates:** For Staging and Production environments, it's assumed that appropriate AWS Certificate Manager (ACM) certificates for custom domains are already provisioned in `us-east-1` and their ARNs are provided. For Development, CloudFront's default certificate will be used.
* **No WAF Integration (Initial):** While the CloudFront module supports WAF integration, it's assumed that a WAF Web ACL is not initially required or will be managed separately.
---
## 5. Design Decisions & Rationale
### a. Environment Isolation
**Decision:** We create **three private S3 buckets** to act as remote backend storage for the Terraform state, one for each environment (dev, staging, prod).
**Rationale:**
* **Isolation of State:** This approach isolates the Terraform state for each environment. In the event of a bucket being destroyed, corrupted, or compromised, only that specific environment's state is affected, minimizing blast radius and ensuring high availability for other environments.
* **Security:** Each state bucket is configured with versioning, server-side encryption (KMS), and strict access policies, further enhancing the security of the Terraform state.
* **Lifecycle Management:** Allows for independent lifecycle management and potential rollback for each environment's infrastructure.
### b. Static Content Storage (S3 Buckets)
**Decision:** For each environment (dev, staging, prod), **three dedicated S3 buckets** (`auth`, `info`, `customers`) are created using the `s3_bucket_secure` module.
**Rationale:**
* **Content Segmentation & Isolation:** Separating content into distinct buckets (e.g., `/auth` for authentication-related assets, `/info` for general information, `/customers` for customer-specific data) improves organization and allows for granular access control. This means **no single bucket holds data for multiple environments or multiple content types.** Each `Storage_BucketX_env` is an independent S3 bucket.
* **Example Bucket Structure:**
    ```
    ├── dev/
    │   ├── dev-beyond-inco-auth  (for /auth content)
    │   ├── dev-beyond-inco-info  (for /info content)
    │   └── dev-beyond-inco-customers (for /customers content)
    │
    ├── staging/
    │   ├── stg-beyond-inco-auth  (for /auth content)
    │   ├── stg-beyond-inco-info  (for /info content)
    │   └── stg-beyond-inco-customers (for /customers content)
    │
    └── prod/
    │   ├── prod-beyond-inco-auth  (for /auth content)
    │   ├── prod-beyond-inco-info  (for /info content)
    │   └── prod-beyond-inco-customers (for /customers content)
    ```
* **Security Segmentation:** If one type of content bucket were ever compromised, the impact would be limited to that specific content type, rather than exposing all static assets of the application.
* **Easier Management and Deployment:** Teams can independently manage and deploy updates to specific content areas without affecting others. For instance, an `update to the login page's CSS` won't risk breaking a customer dashboard.
* **Clear Organization:** It provides a logical and intuitive way to organize your static assets, making it easier for developers and operations teams to understand where different types of content reside.
* **Security Features (Built-in):**
    * **Versioning Enabled:** Ensures protection against accidental deletions and and provides a history of all object versions, facilitating rollbacks.
    * **Server-Side Encryption with KMS:** All objects are encrypted at rest using AWS KMS, providing a strong layer of data protection. KMS keys are managed by AWS, adding another layer of security.
    * **Public Access Block:** All buckets have public access explicitly blocked, preventing direct anonymous access to the content and forcing access through the CloudFront CDN, which acts as a secure gateway.
    * **BucketOwnerEnforced Ownership:** Ensures that new objects uploaded to the bucket are owned by the bucket owner, simplifying access management.
### c. CDN Implementation (CloudFront with OAC)
**Decision:** A **CloudFront distribution with Origin Access Control (OAC)** is deployed for each environment using the `cloudfront_wth_oac` module.
**Rationale:**
* **Secure Content Delivery:** CloudFront caches content geographically closer to users, reducing latency and improving load times. OAC is used to secure access to the S3 origins. Instead of older Origin Access Identities (OAIs), OAC provides a more robust and granular way for CloudFront to fetch content from S3, restricting direct public access to the buckets.
* **Path-Based Routing:** The CloudFront distributions are configured with specific path behaviors (`/auth/*`, `/info/*`, `/customers/*`) to direct requests to their respective S3 origin buckets. This allows a single CDN endpoint to serve content from multiple logical locations within the application.
* **HTTPS Enforcement:** All HTTP requests are automatically redirected to HTTPS, ensuring that data is always transmitted securely.
* **Custom Domains & Certificates:** The module supports custom domain names and ACM certificates (for staging and production), providing a professional user experience. For development, it defaults to CloudFront's provided domain and certificate.
### d. Modularity
**Decision:** The IaC code is structured into **reusable Terraform modules**.
**Rationale:**
* **DRY (Don't Repeat Yourself) Principle:** Modules prevent code duplication, especially for common resources like secure S3 buckets and CloudFront distributions, ensuring consistency across environments.
* **Maintainability:** Changes or updates to infrastructure components can be made in a single module and propagated across all environments that use it, simplifying maintenance.
* **Reusability:** Modules can be easily reused in other projects or across different parts of the same project.
* **Readability & Organization:** Breaking down complex infrastructure into smaller, logical units makes the codebase easier to understand, navigate, and manage.
---
## 6. Access Control & Security Best Practices
The solution is designed with the principle of **least privilege** at its core.
* **Programmatic User `beyondInco`:**
    * The `beyondInco` user, while having `Full access to s3 and cloudfront`, is **restricted to resources tagged with `project = "beyondinco"`**. This is a critical security measure ensuring that the programmatic user can only interact with the intended project's resources and cannot accidentally or maliciously affect other resources in the AWS account.
* **S3 Bucket Policies (for Content Buckets):**
    * Each static content S3 bucket has a policy (created dynamically within `static_content_stack/main.tf` via `data "aws_iam_policy_document"`) that explicitly grants `s3:GetObject` permissions *only* to the CloudFront distribution's service principal, and *only* when the request originates from the specific CloudFront distribution ARN. This ensures that S3 content is accessible **exclusively through CloudFront**.
* **CloudFront Origin Access Control (OAC):**
    * OAC is utilized to establish a trust relationship between CloudFront and the S3 buckets. This ensures that CloudFront is the only entity permitted to read content directly from the S3 origins, blocking any attempts to access the S3 buckets directly via their public endpoints.
* **S3 Bucket Policies (for State Buckets):**
    * The `s3_state_bucket` module includes a bucket policy that:
        * Denies insecure transport (`http`).
        * Denies unencrypted object uploads.
        * Gives `s3:ListBucket` permissions on the bucket level and `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` permissions on the `terraform.tfstate` file and its lock file to specific `allowed_role_arns`. This ensures that only authorized IAM roles can manage the Terraform state.
---
## 7 Multi-Region & Reliability Improvements

### Active-Passive Failover Configuration

The can enhanced implements as **active-passive failover model** where:

- **Primary regions** handle all traffic during normal operations
- **Secondary regions** remain synchronized but passive
- **MRAP failover controls** enable rapid switching during outages[45][46]
- **Cross-region replication** maintains data consistency across regions[37][40]

### Multi-Region Access Points Benefits

**Global Endpoint Management:**
- Single global endpoint per content type eliminates complex DNS management[39][42]
- Automatic routing to closest available region reduces latency by up to 60%[39][42]
- Built-in AWS Global Accelerator integration for optimal performance[39][42]

**Disaster Recovery Capabilities:**
- **Failover Controls:** Switch traffic between regions within minutes[45][46]
- **Health Monitoring:** Automatic detection of regional failures[45][46]
- **Manual Override:** Administrative control for planned maintenance[45][46]
---
## 7. Deployment Steps
To deploy this infrastructure across your environments, follow these general steps:
1.  **Clone the Repository:**
    ```bash
    git clone <your-repo-url>
    cd <your-repo-directory>/1 IAC
    ```
2.  **Initialize Backend Storage (One-Time Setup per environment):**
    First, set up the S3 buckets that will store your Terraform state files. This should be done for each environment.
    
    **Note:** This is a **first-time setup assumption**. If S3 state buckets already exist and are configured, this step can be skipped and you can directly use the bucket names in the next stage as Terraform backend references.
    
    * Navigate to the root directory:
        ```
        cd 1\ IAC/backend-storage-setup/
        ```
    * Run the Python backend setup script:
        ```
        python3 setup_terraform_backends.py
        ```
        
    **What this script does:**
    - Reads bucket names from `bucket_names.txt`
    - Creates S3 buckets for Terraform state storage (if they don't exist)
    - Configures bucket versioning and encryption
    - Creates policy for tf.lock file for state locking
    - Sets up the necessary backend infrastructure for all environments
    
    **Customization:**
    - Modify `bucket_names.txt` to change bucket names as needed
    - The script handles the creation of backend resources automatically
    - Bucket names and configurations can be customized before running the script

3.  **Deploy Application CDN Infrastructure:**
    Once the backend state buckets are provisioned, you can deploy the main application infrastructure.
    * Navigate to the `app-cdn-infra` directory:
        ```bash
        cd ../app-cdn-infra
        ```
    * For each environment (dev, staging, prod), run:
        ```bash
        # Example for Development environment
        terraform init -reconfigure -backend-config=env/dev/backend.hcl
        terraform apply -var-file=env/dev/dev.tfvars
        ```
        *Repeat for `staging` and `prod` by replacing `dev` with the respective environment name in both `backend-config` and `var-file`.*
        *Remember to provide the `acm_certificate_arn` in `staging.tfvars` and `prod.tfvars` if using custom domains.*
4.  **Verify Deployment:**
    * After `terraform apply` completes for `app-cdn-infra`, check the CloudFront distribution domain names and test accessing the paths (`/auth/`, `/info/`, `/customers/`) to ensure content is served correctly.
    * Inspect your AWS console to confirm S3 buckets are versioned, encrypted, and have appropriate public access blocks and bucket policies.
5.  **Clean Up (Optional):**
    To destroy the infrastructure for an environment:
    * Navigate to the respective `app-cdn-infra` environment directory.
    * Run `terraform destroy -var-file=env/<env-name>/<env-name>.tfvars`.
    * Similarly, navigate to `backend-storage-setup` and run `terraform destroy` for the state bucket.
AS this is a code submition and i need 
Documentation: Clearly documented design decisions, assumptions, and rationale
'