env               = "dev"
region            = "us-east-1"
bucket_name       = "tfstate-dev-beyondinco-<account-id>"
enable_kms        = true
allowed_role_arns = [
  "arn:aws:iam::<account-id>:role/runner-dev-terraform-apply"
]
state_key = "envs/dev/terraform.tfstate"
tags = { project = "beyond_inco", owner = "platform", env = "dev" }
