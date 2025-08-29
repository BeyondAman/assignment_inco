env               = "staging"
region            = "us-east-1"
bucket_name       = "tfstate-staging-beyondinco-<account-id>"
enable_kms        = true
allowed_role_arns = [
  "arn:aws:iam::<account-id>:role/runner-staging-terraform-apply"
]
state_key = "envs/staging/terraform.tfstate"
tags = { project = "beyond_inco", owner = "platform", env = "staging" }
