# Baseball Analytics Data Platform

This repository contains a comprehensive, secure, and cost-efficient data platform implementation for baseball analytics. It is structured to handle end-to-end processing from raw data ingestion to analytical aggregates.

## Project Structure

- `infra/`: Terraform (IaC) for AWS resources (S3, KMS, IAM, Budgets, Config).
- `pipelines/`: Databricks Job configurations, cluster policies, and PySpark ingestion scripts.
- `sql/`: Production-grade SQL for team performance and efficiency analysis.
- `finops/`: Cost analysis reports and optimization controls.
- `data/raw/`: Sample data files for ingestion.
- `docs/`: Detailed design documentation, architecture choices, and technical trade-offs.

## Key Deliverables

### Section A: Infrastructure (AWS)
- **Provisioned:** 2 S3 buckets (landing/curated) with TLS, SSE-KMS, and lifecycle rules.
- **Security:** Custom KMS CMK with least-privilege policies; IAM Instance Profile for Databricks.
- **Governance:** AWS Budget with an 80% alert threshold and an AWS Config rule to prohibit public S3 access.
- **Verification:** Run `terraform validate` and see `infra/terraform_plan.txt` for the execution plan.

### Section B: Databricks Job Enablement
- **Cluster Policy:** Enforces 15-minute autotermination, restricted node types, and LTS runtimes to ensure cost and stability.
- **Ingestion Job:** `pipelines/ingestion_job.py` provides an idempotent, schema-enforcing pipeline that handles all 5 core datasets with basic Data Quality (DQ) checks.

### Section C: FinOps Optimization
- **Analysis:** Top cost drivers (EC2 at 73%) identified and analyzed in `finops/cost_analysis.md`.
- **Controls:** Implemented S3 lifecycle transitions and a tag-based AWS Budget to enforce cost discipline.

### Section D: ETL Development
- **Efficiency Aggregate:** `sql/team_efficiency.sql` calculates team-year payroll, HR, Batting Average, Slugging, and HR-per-Million with strict handling of edge cases and no double-counting.

## How to Test

1. **Infrastructure:**
   ```bash
   cd infra && terraform validate && terraform plan
   ```
2. **Ingestion Pipeline:**
   Review `pipelines/ingestion_job.py` for logic and `pipelines/job_config.json` for orchestration.
3. **SQL Analytics:**
   The logic in `sql/team_efficiency.sql` can be verified against the schema provided in `ingestion_job.py`.

## Design & Assumptions
For a deep dive into the architecture and security choices, please refer to [docs/README.md](docs/README.md).

---
**Author:** Daniel Chi
**Date:** April 9, 2026
