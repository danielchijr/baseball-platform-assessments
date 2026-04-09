# --- Cost Governance: Monthly Budget Alerts ---
# Provides proactive monitoring to prevent unexpected cloud spend 
# on resources tagged with the application identifier.
resource "aws_budgets_budget" "cost_limit" {
  name              = "monthly-budget-alert"
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "App$${var.common_tags.App}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.notification_email]
  }
}

# --- Security Compliance: AWS Config Rules ---
# Automated auditing to ensure S3 buckets adhere to the "Public Access Prohibited" 
# policy as required by studio security standards.
resource "aws_config_config_rule" "s3_public_prohibited" {
  name = "s3-bucket-public-read-prohibited"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  tags = var.common_tags
}