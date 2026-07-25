# Partial backend config: bucket/region/dynamodb_table come from
# -backend-config at init time (see README) so the bucket name - which
# includes the AWS account ID - never has to be committed. Only the state
# key is fixed here, and it's unique per environment so dev/stage/prod
# never share a state file.
terraform {
  backend "s3" {
    key     = "prod/terraform.tfstate"
    encrypt = true
  }
}
