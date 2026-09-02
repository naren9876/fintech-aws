#!/bin/bash
# ============================================================
# ONE-TIME bootstrap (the chicken-and-egg every org has):
# creates the 4 things CI needs before CI can exist.
# Everything else is managed by the pipelines. Run in CloudShell
# or any terminal authenticated to the target account.
# ============================================================
set -e

ACCOUNT_ID=840080485121
REPO="naren9876/fintech-aws"
BUCKET="fintech-tfstate-${ACCOUNT_ID}"
REGION="us-east-1"

echo "1/4 State bucket (versioned + encrypted)..."
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null || echo "  bucket exists"
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "2/4 State lock table..."
aws dynamodb create-table --table-name fintech-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region "$REGION" 2>/dev/null || echo "  table exists"

echo "3/4 GitHub OIDC provider..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com 2>/dev/null || echo "  provider exists"

echo "4/4 CI role (trust locked to ${REPO})..."
cat > /tmp/trust.json << TRUST
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:${REPO}:*" }
    }
  }]
}
TRUST
aws iam create-role --role-name github-actions-fintech \
  --assume-role-policy-document file:///tmp/trust.json 2>/dev/null || echo "  role exists"
aws iam attach-role-policy --role-name github-actions-fintech \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo ""
echo "Role ARN (put this in GitHub -> Settings -> Actions -> Variables as AWS_ROLE_ARN):"
aws iam get-role --role-name github-actions-fintech --query 'Role.Arn' --output text
