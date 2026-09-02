terraform {
  backend "s3" {
    bucket         = "fintech-tfstate-840080485121"
    key            = "fintech/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fintech-tfstate-lock"
  }
}
