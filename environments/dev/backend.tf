terraform {
  backend "s3" {
    bucket         = "fanvault-tfstate-dev-899071933396"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fanvault-tf-locks-dev"
    encrypt        = true
  }
}
