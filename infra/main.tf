terraform {
  backend "s3" {
    bucket         = "baseball-platform-terraform-state"
    key            = "platform-test/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  # Mock configurations for local validation/offline planning
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_key"
  secret_key                  = "mock_secret"
}

# --- Data Platform Encryption (KMS) ---
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for data platform S3 buckets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_policy.json
  tags                    = var.common_tags
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.project_name}-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowComputeRoleAccess"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.databricks_job_role.arn]
    }
  }
}

# --- S3 Storage Layer (Medallion Architecture) ---
resource "aws_s3_bucket" "landing" {
  bucket = "${var.project_name}-landing-${var.environment}"
  tags   = var.common_tags
}

resource "aws_s3_bucket" "curated" {
  bucket = "${var.project_name}-curated-${var.environment}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "curated_versioning" {
  bucket = aws_s3_bucket.curated.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Security & Governance Enforcement ---
resource "aws_s3_bucket_public_access_block" "landing_block" {
  bucket                  = aws_s3_bucket.landing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "curated_block" {
  bucket                  = aws_s3_bucket.curated.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "landing_policy" {
  bucket = aws_s3_bucket.landing.id
  policy = data.aws_iam_policy_document.s3_enforcement_landing.json
}

data "aws_iam_policy_document" "s3_enforcement_landing" {
  statement {
    sid     = "EnforceTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.landing.arn,
      "${aws_s3_bucket.landing.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "curated_policy" {
  bucket = aws_s3_bucket.curated.id
  policy = data.aws_iam_policy_document.s3_enforcement_curated.json
}

data "aws_iam_policy_document" "s3_enforcement_curated" {
  statement {
    sid     = "EnforceTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.curated.arn,
      "${aws_s3_bucket.curated.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "landing_lifecycle" {
  bucket = aws_s3_bucket.landing.id
  rule {
    id     = "ArchiveRawData"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 90
    }
  }
}

# --- Identity & Access Management ---
resource "aws_iam_role" "databricks_job_role" {
  name = "databricks-job-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" } 
    }]
  })
}

resource "aws_iam_instance_profile" "databricks_profile" {
  name = "databricks-job-instance-profile"
  role = aws_iam_role.databricks_job_role.name
}

resource "aws_iam_role_policy" "databricks_s3_policy" {
  name = "databricks-s3-access"
  role = aws_iam_role.databricks_job_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.landing.arn, "${aws_s3_bucket.landing.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [aws_s3_bucket.curated.arn, "${aws_s3_bucket.curated.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource = [aws_kms_key.s3_key.arn]
      }
    ]
  })
}

resource "aws_iam_role" "ci_cd_role" {
  name = "platform-ci-cd-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ci_cd_policy" {
  name = "ci-cd-infra-policy"
  role = aws_iam_role.ci_cd_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:CreateBucket", "s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock",
          "kms:CreateKey", "kms:PutKeyPolicy", "iam:CreateRole", "iam:PutRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}