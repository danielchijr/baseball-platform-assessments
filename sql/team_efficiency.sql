/*
Rationale:
- Correctness: Aggregates Batting data across all players and stints to ensure one row per teamID/yearID.
- Handling Edge Cases: Uses a LEFT JOIN to include teams that may not have salary data (e.g., historical data or incomplete records).
- Idempotency: The query is deterministic; re-running it on the same data produces identical results.
- Performance: Filters for non-null AB to avoid division-by-zero errors and aggregates before joining to minimize the dataset.
- Data Quality: Includes checks to ensure that AB and salary are greater than zero before calculating dependent metrics.

Note: In a production environment like Databricks, this would be written as a Delta table using `CREATE OR REPLACE TABLE team_efficiency AS ...`.
*/

WITH team_batting AS (
    SELECT 
        teamID,
        yearID,
        SUM(AB) AS total_ab,
        SUM(H) AS total_h,
        SUM("2B") AS total_2b,
        SUM("3B") AS total_3b,
        SUM(HR) AS total_hr,
        -- Total Bases = H + 2B + 2*3B + 3*HR
        SUM(H + "2B" + 2*"3B" + 3*HR) AS total_bases
    FROM 
        curated.Batting
    GROUP BY 
        teamID, 
        yearID
),
team_salaries AS (
    SELECT 
        teamID,
        yearID,
        SUM(salary) AS total_payroll
    FROM 
        curated.Salaries
    GROUP BY 
        teamID, 
        yearID
)
SELECT 
    b.teamID,
    b.yearID,
    COALESCE(s.total_payroll, 0) AS total_payroll,
    b.total_ab AS AB,
    b.total_hr AS HR,
    -- Batting Average (BA)
    CASE WHEN b.total_ab > 0 THEN ROUND(b.total_h * 1.0 / b.total_ab, 3) ELSE 0 END AS BA,
    -- Slugging Percentage (SLG)
    CASE WHEN b.total_ab > 0 THEN ROUND(b.total_bases * 1.0 / b.total_ab, 3) ELSE 0 END AS SLG,
    -- HR per Million Dollars
    CASE WHEN s.total_payroll > 0 THEN ROUND(b.total_hr / (s.total_payroll / 1000000.0), 2) ELSE 0 END AS HR_per_Million
FROM 
    team_batting b
LEFT JOIN 
    team_salaries s ON b.teamID = s.teamID AND b.yearID = s.yearID
ORDER BY 
    b.yearID DESC, 
    b.teamID ASC;
