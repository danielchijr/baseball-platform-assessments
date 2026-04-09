# Baseball Analytics Platform: Design and Implementation

## Architecture Choices

The platform is designed as a cloud-native, modular data architecture using AWS for infrastructure and Databricks for data processing.

### 1. Infrastructure (Terraform)
- **S3 Zones:** Data is logically separated into `landing` (raw CSVs) and `curated` (processed Delta tables).
- **Security:**
    - **Encryption:** All S3 objects are encrypted at rest using a dedicated KMS Customer Managed Key (CMK) with a least-privilege policy.
    - **TLS Enforced:** Bucket policies deny any insecure (non-HTTPS) traffic.
    - **No Public Access:** Public access blocks are applied to both buckets, and an AWS Config rule ensures this remains in effect.
- **IAM:** The Databricks Job Role is restricted to read access on `landing` and write/delete access on `curated` only.

### 2. Data Pipeline (PySpark)
- **Ingestion Script (`pipelines/ingestion_job.py`):**
    - **Strict Schema Enforcement:** Prevents dirty data from entering the curated zone.
    - **Idempotency:** Uses `mode("overwrite")` to ensure that re-running a job produces a clean, consistent state.
    - **Data Quality:** Filters for null primary keys and validates year ranges (1800-2025).
- **Partitioning:** The `Batting` table is partitioned by `yearID` to optimize queries that filter by season.

### 3. Cost Control Measures (FinOps)
- **AWS Budgets:** A tag-filtered budget alert is set to 80% of a configurable threshold ($100 default).
- **Cluster Policies:**
    - **Autotermination:** Fixed at 15 minutes to eliminate idle cluster costs.
    - **Restricted Node Types:** Limits users to m5.large/xlarge to prevent accidental high-cost instance usage.
    - **Max Workers:** Capped at 10 workers per job to prevent "runaway" scaling.
- **S3 Lifecycle:** Automated transition to Infrequent Access after 30 days and deletion of raw files after 90 days.

## Databricks Admin & Observability

### Access Control (Unity Catalog)
In a production Unity Catalog setup:
- **Catalogs:** `main` (prod), `dev` (non-prod).
- **Schemas:** `raw` (landing), `curated` (processed), `analytics` (aggregated).
- **Secrets:** AWS credentials and API keys would be stored in **Databricks Secret Scopes** (backed by AWS Secrets Manager) and accessed via `dbutils.secrets.get()`.

### Observability
- **Retry Policy:** Configured in `job_config.json` to retry 3 times with a 5-minute interval.
- **Failure Alerts:** Email notifications are configured for job failures and starts to ensure the team is aware of pipeline status.
- **Job Clusters:** Enforced via policy to ensure lower cost compared to interactive clusters.

## Testing Strategy

1. **Infra Validation:**
    ```bash
    cd infra && terraform validate && terraform plan
    ```
2. **Pipeline Local Test:**
    The `ingestion_job.py` is designed to be runnable locally for logic verification (though Spark must be installed).
3. **ETL Correctness:**
    The `team_efficiency.sql` includes a Rationale section explaining the aggregation logic to prevent double counting.

## Known Gaps & Future Improvements

- **Schema Evolution:** Currently using a strict schema. Future iterations should support Delta Lake's schema evolution features.
- **CI/CD Integration:** The `.github/workflows/terraform-ci.yml` is a skeleton; a full implementation would include environment-specific variables and state locking.
- **Monitoring Dashboards:** Integrating Databricks SQL with a visualization tool (e.g., Tableau or PowerBI) would provide better visibility into the "Efficiency Index" metrics.
- **Delta Table Optimization:** Adding `Z-ORDER` on `teamID` would further optimize analytical queries.
