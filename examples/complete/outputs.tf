output "bucket_id"                   { value = module.s3.bucket_id }
output "bucket_arn"                  { value = module.s3.bucket_arn }
output "bucket_domain_name"          { value = module.s3.bucket_domain_name }
output "bucket_regional_domain_name" { value = module.s3.bucket_regional_domain_name }
output "bucket_region"               { value = module.s3.bucket_region }
output "bucket_hosted_zone_id"       { value = module.s3.bucket_hosted_zone_id }
output "replication_role_arn"        { value = module.s3.replication_role_arn }
