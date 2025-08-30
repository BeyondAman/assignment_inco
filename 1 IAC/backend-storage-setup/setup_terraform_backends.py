import boto3
import json
import botocore
import sys
import os
import time

# --- Configuration Variables ---
# Your desired AWS region (e.g., us-east-1, ap-south-1)
# This is the only variable you need to configure.
AWS_REGION = "us-east-1"

# File containing the base names for the S3 buckets (e.g., tfstate-dev-beyondinco)
BUCKET_NAMES_FILE = "bucket_names.txt"

# IAM Policy template file
POLICY_TEMPLATE_FILE = "terraform_s3_policy_template.json"

# Base name for the IAM Roles (e.g., beyond-inco-terraform-dev-role)
IAM_ROLE_BASE_NAME = "beyond-inco-terraform"

# Base name for the IAM Policies (e.g., BeyondIncoTerraformDevStatePolicy)
IAM_POLICY_BASE_NAME = "BeyondIncoTerraform"

# --- Boto3 Clients ---
try:
    s3_client = boto3.client("s3", region_name=AWS_REGION)
    kms_client = boto3.client("kms", region_name=AWS_REGION)
    iam_client = boto3.client("iam")
    sts_client = boto3.client("sts", region_name=AWS_REGION)
except botocore.exceptions.ClientError as e:
    print(f"Error: Failed to create Boto3 clients. Please check your AWS credentials and region.")
    print(e)
    sys.exit(1)

# --- Helper Functions ---

def get_assumer_principal_arn():
    """Fetches the ARN of the IAM principal running the script."""
    try:
        response = sts_client.get_caller_identity()
        return response["Arn"]
    except botocore.exceptions.ClientError as e:
        print(f"Error: Could not retrieve caller identity. Please ensure your AWS CLI is configured.")
        print(e)
        sys.exit(1)

def get_account_id():
    """Fetches the current AWS account ID."""
    try:
        response = sts_client.get_caller_identity()
        return response["Account"]
    except botocore.exceptions.ClientError as e:
        print(f"Error: Could not retrieve AWS Account ID. Please ensure your AWS CLI is configured.")
        print(e)
        sys.exit(1)

def create_iam_role(role_name, assumable_principal_arn):
    """Creates an IAM role with a trust policy allowing a specific principal to assume it."""
    print(f"Creating IAM role: {role_name}...")
    assume_role_policy_document = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"AWS": assumable_principal_arn},
                "Action": "sts:AssumeRole",
            }
        ],
    }
    try:
        response = iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(assume_role_policy_document),
            Description=f"IAM role for Terraform operations in {role_name.split('-')[-2]} environment for Beyond Inco project.",
        )
        print(f"Role '{role_name}' created with ARN: {response['Role']['Arn']}")
        return response["Role"]["Arn"]
    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "EntityAlreadyExists":
            print(f"Role '{role_name}' already exists. Retrieving ARN.")
            return iam_client.get_role(RoleName=role_name)["Role"]["Arn"]
        else:
            print(f"Error creating role '{role_name}': {e}")
            sys.exit(1)

def create_s3_bucket(bucket_name):
    """Creates an S3 bucket with versioning and public access blocks."""
    print(f"Creating S3 bucket: {bucket_name}...")
    try:
        if AWS_REGION == "us-east-1":
            # us-east-1 is a special case; location constraint is not specified
            s3_client.create_bucket(Bucket=bucket_name)
        else:
            s3_client.create_bucket(
                Bucket=bucket_name,
                CreateBucketConfiguration={"LocationConstraint": AWS_REGION},
            )
        print(f"Bucket '{bucket_name}' created.")
    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "BucketAlreadyOwnedByYou":
            print(f"Bucket '{bucket_name}' already exists and is owned by you. Skipping creation.")
        else:
            print(f"Error creating bucket '{bucket_name}': {e}")
            sys.exit(1)

    print(f"Enabling versioning for '{bucket_name}'...")
    s3_client.put_bucket_versioning(
        Bucket=bucket_name,
        VersioningConfiguration={"Status": "Enabled"},
    )
    print(f"Versioning enabled.")

    print(f"Blocking all public access for '{bucket_name}'...")
    s3_client.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )
    print(f"Public access blocked.")

    print(f"Enforcing bucket ownership controls for '{bucket_name}'...")
    s3_client.put_bucket_ownership_controls(
        Bucket=bucket_name,
        OwnershipControls={
            'Rules': [
                {
                    'ObjectOwnership': 'BucketOwnerEnforced'
                },
            ]
        }
    )
    print(f"Bucket ownership controls enforced.")
    return f"arn:aws:s3:::{bucket_name}"

def create_kms_key(env):
    """Creates a KMS key and alias for the bucket."""
    kms_key_description = f"KMS key for Terraform state bucket for {env} environment"
    kms_key_alias = f"alias/{IAM_ROLE_BASE_NAME}-{env}-state-key"

    print(f"Creating KMS key for {env} environment...")
    try:
        response = kms_client.create_key(
            Description=kms_key_description,
            KeyUsage="ENCRYPT_DECRYPT",
            Tags=[{'TagKey': 'Environment', 'TagValue': env.capitalize()}]
        )
        key_id = response["KeyMetadata"]["KeyId"]
        print(f"KMS key created with ID: {key_id}")
    except botocore.exceptions.ClientError as e:
        if "AlreadyExistsException" in str(e): # This is not the exact error code for KMS key, but for alias
            print(f"KMS key for {env} might already exist. Attempting to find it by alias...")
            try:
                response = kms_client.list_aliases(
                    SearchAliases=kms_key_alias.replace("alias/", "")
                )
                key_id = response["Aliases"][0]["TargetKeyId"]
                print(f"Found existing KMS key ID: {key_id}")
            except (botocore.exceptions.ClientError, IndexError):
                print(f"Could not find or create KMS key for {env}. Exiting.")
                sys.exit(1)
        else:
            print(f"Error creating KMS key: {e}")
            sys.exit(1)

    try:
        kms_client.create_alias(
            AliasName=kms_key_alias,
            TargetKeyId=key_id,
        )
        print(f"KMS alias '{kms_key_alias}' created.")
    except botocore.exceptions.ClientError as e:
        if "AlreadyExistsException" in str(e):
            print(f"KMS alias '{kms_key_alias}' already exists.")
        else:
            print(f"Error creating KMS alias: {e}")
            sys.exit(1)

    return f"arn:aws:kms:{AWS_REGION}:{get_account_id()}:key/{key_id}"

def enable_kms_encryption(bucket_name, kms_key_arn):
    """Enables default KMS encryption on the S3 bucket."""
    print(f"Enabling server-side encryption with KMS for '{bucket_name}'...")
    try:
        s3_client.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "aws:kms",
                            "KMSMasterKeyID": kms_key_arn,
                        },
                        "BucketKeyEnabled": True,
                    }
                ]
            },
        )
        print(f"KMS encryption enabled for '{bucket_name}'.")
    except botocore.exceptions.ClientError as e:
        print(f"Error enabling KMS encryption for '{bucket_name}': {e}")
        sys.exit(1)

def create_and_attach_iam_policy(env, bucket_arn, kms_key_arn, role_arn):
    """Creates a specific IAM policy for an environment and attaches it to the role."""
    policy_name = f"{IAM_POLICY_BASE_NAME}{env.capitalize()}StatePolicy"
    print(f"Generating and attaching IAM policy for {env} environment: {policy_name}...")

    with open(POLICY_TEMPLATE_FILE, "r") as f:
        policy_template = f.read()

    # Replace placeholders for the specific environment
    policy_template = policy_template.replace("BUCKET_ARN_PLACEHOLDER", bucket_arn)
    policy_template = policy_template.replace("KMS_KEY_ARN_PLACEHOLDER", kms_key_arn)
    policy_template = policy_template.replace("ENV_PREFIX", env) # For s3:prefix condition

    policy_document = json.loads(policy_template)

    # Create or update the IAM policy
    try:
        response = iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document),
            Description=f"IAM policy for Terraform state management in {env} environment.",
        )
        policy_arn = response["Policy"]["Arn"]
        print(f"IAM policy '{policy_name}' created with ARN: {policy_arn}")
    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "EntityAlreadyExists":
            print(f"Policy '{policy_name}' already exists. Attempting to update it.")
            policy_arn = iam_client.get_policy(
                PolicyArn=f"arn:aws:iam::{get_account_id()}:policy/{policy_name}"
            )["Policy"]["Arn"]

            # Create a new policy version (and set as default)
            iam_client.create_policy_version(
                PolicyArn=policy_arn,
                PolicyDocument=json.dumps(policy_document),
                SetAsDefault=True,
            )
            print(f"Policy '{policy_name}' updated successfully.")
        else:
            print(f"Error creating/updating IAM policy '{policy_name}': {e}")
            sys.exit(1)

    # Attach policy to role
    try:
        iam_client.attach_role_policy(
            RoleName=f"{IAM_ROLE_BASE_NAME}-{env}-role", # Construct the role name
            PolicyArn=policy_arn,
        )
        print(f"Policy '{policy_name}' attached to role '{IAM_ROLE_BASE_NAME}-{env}-role' successfully.")
    except botocore.exceptions.ClientError as e:
        print(f"Error attaching policy to role '{IAM_ROLE_BASE_NAME}-{env}-role': {e}")
        sys.exit(1)


def main():
    """Main execution function to set up backends, KMS, roles, and policies."""
    
    print("--- Starting Python Terraform Backend Setup ---")
    print(f"AWS Region: {AWS_REGION}")
    print("------------------------------------------------")
    
    assumer_principal_arn = get_assumer_principal_arn()
    account_id = get_account_id()

    print(f"Detected Assumer Principal ARN: {assumer_principal_arn}")
    print(f"Detected AWS Account ID: {account_id}")

    try:
        with open(BUCKET_NAMES_FILE, "r") as f:
            bucket_base_names = [line.strip() for line in f.readlines() if line.strip()]
    except FileNotFoundError:
        print(f"Error: '{BUCKET_NAMES_FILE}' not found.")
        sys.exit(1)

    if len(bucket_base_names) != 3:
        print(f"Error: '{BUCKET_NAMES_FILE}' must contain exactly 3 bucket names (dev, stg, prod).")
        sys.exit(1)

    environments = ["dev", "stg", "prod"]

    for i, env in enumerate(environments):
        bucket_base_name = bucket_base_names[i]
        
        # This is the change you requested: The bucket name will not have the account ID.
        full_bucket_name = bucket_base_name

        role_name = f"{IAM_ROLE_BASE_NAME}-{env}-role"

        print(f"\n--- Setting up for {env.upper()} Environment ---")

        # 1. Create IAM Role
        role_arn = create_iam_role(role_name, assumer_principal_arn)

        # 2. Create S3 Bucket
        bucket_arn = create_s3_bucket(full_bucket_name)

        # 3. Create KMS Key
        kms_key_arn = create_kms_key(env)

        # 4. Enable KMS Encryption on S3 Bucket
        enable_kms_encryption(full_bucket_name, kms_key_arn)

        # 5. Create and Attach IAM Policy
        create_and_attach_iam_policy(env, bucket_arn, kms_key_arn, role_arn)

        print(f"\n--- {env.upper()} Environment Setup Complete ---")
        print(f"  IAM Role: {role_name} ({role_arn})")
        print(f"  S3 Bucket: {full_bucket_name} ({bucket_arn})")
        print(f"  KMS Key: {kms_key_arn}")
        print("\n  Example Terraform Backend Configuration:")
        print(f"  terraform {{")
        print(f"    backend \"s3\" {{")
        print(f"      bucket       = \"{full_bucket_name}\"")
        print(f"      key          = \"state/terraform.tfstate\"")
        print(f"      region       = \"{AWS_REGION}\"")
        print(f"      encrypt      = true")
        print(f"      use_lockfile = true")
        print(f"    }}")
        print(f"  }}")
        print(f"  ------------------------------------------------")

    print("\n------------------------------------------------")
    print("--- All Terraform Backends, KMS, Roles, and Policies Setup Complete! ---")
    print("You can now use the generated IAM roles to run Terraform for each environment.")
    print("Remember to configure your local AWS CLI or CI/CD to assume the correct role for each environment.")

if __name__ == "__main__":
    main()