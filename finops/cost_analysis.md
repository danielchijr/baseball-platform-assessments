# FinOps Cost Analysis and Optimization

## 1. Current Cost Analysis (Based on aws_costs.csv)

| Service | Total Cost (USD) | % of Spend |
|---------|------------------|------------|
| AmazonEC2 | $1,085.00 | 73.4% |
| EC2-Other (EBS) | $216.30 | 14.6% |
| AmazonS3 | $144.45 | 9.8% |
| AmazonCloudWatch | $26.60 | 1.8% |
| AWSLambda | $4.75 | 0.3% |
| AWSKMS | $2.10 | 0.1% |
| **Total** | **$1,479.20** | **100%** |

### Top Drivers
- **EC2 (m5.large):** Main compute cost for data processing.
- **EBS Volume Usage:** Storage for EC2 instances and intermediate processing.
- **S3 ByteHrs:** Storage for landing and curated data zones.

## 2. Savings Recommendations

### A. Spot Instances for Dev/Test (Estimated Savings: 60-90% on EC2)
- **Action:** Configure Databricks clusters in the `dev` environment to use Spot instances with On-Demand fallback.
- **Estimated Savings:** ~$500 - $800 / month.

### B. S3 Lifecycle & IA Transition (Estimated Savings: 30-50% on S3 Storage)
- **Action:** Move raw data to `STANDARD_IA` after 30 days and expire after 90 days.
- **Estimated Savings:** ~$40 - $70 / month.

### C. Compute Savings Plans (Estimated Savings: 20-30% on remaining On-Demand)
- **Action:** Commit to a 1-year or 3-year Savings Plan for steady-state production workloads.
- **Estimated Savings:** ~$60 - $100 / month.

## 3. Implemented Controls (As-Code)

### Control 1: S3 Lifecycle Management (`infra/main.tf`)
- Automated transition and expiration rules for the `landing` bucket to prevent uncontrolled storage growth.

### Control 2: Tighter Databricks Cluster Policy (`pipelines/cluster_policy.json`)
- **Autotermination:** Fixed at 15 minutes to prevent idle clusters from burning budget.
- **Worker Limits:** Restricted to a maximum of 10 workers per job.
- **Node Allowlist:** Only cost-effective node types (m5.large/xlarge) are permitted.

### Control 3: AWS Budget with Tag Enforcement (`infra/governance.tf`)
- Configured a monthly budget of $100 with an alert at 80% (threshold variable) specifically filtered by the `App: baseball-analytics` tag.
