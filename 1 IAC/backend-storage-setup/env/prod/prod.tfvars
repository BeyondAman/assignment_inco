env               = "prod"
region            = "us-east-1"
bucket_name       = "tfstate-prod-beyondinco-<account-id>"
enable_kms        = true
allowed_role_arns = [
  "arn:aws:iam::<account-id>:role/runner-prod-terraform-apply"
]
state_key = "envs/prod/terraform.tfstate"
tags = { project = "beyond_inco", owner = "platform", env = "prod" }
