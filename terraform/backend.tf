terraform {
  backend "s3" {
    bucket         = "fintech-tfstate-840080485121"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fintech-tfstate-lock"
    # NOTE: "key" is intentionally ABSENT (partial backend config).
    # Each environment supplies its own state key at init time:
    #   terraform init -backend-config="key=fintech/dev/terraform.tfstate"
    #   terraform init -backend-config="key=fintech/staging/terraform.tfstate"
    # Separate state per env = separate blast radius. A destroy in one
    # state physically cannot touch the other environment.
  }
}
