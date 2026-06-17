terraform {
  backend "s3" {
    bucket         = "fanvault-tfstate-prod-899071933396"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fanvault-tf-locks-prod"
    encrypt        = true
  }
}
