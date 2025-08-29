output "bucket_name" { value = aws_s3_bucket.state.bucket }
output "bucket_arn"  { value = aws_s3_bucket.state.arn }
output "kms_key_arn" { value = try(aws_kms_key.state[0].arn, null) }
