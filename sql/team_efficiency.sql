/*
Team Performance & Financial Efficiency Analysis
------------------------------------------------
Objective: 
Aggregates seasonal batting performance and payroll data to derive 
efficiency metrics (BA, SLG) and financial ROI (HR per Million).

Design Patterns:
- CTEs: Separates aggregation logic from final calculations for maintainability.
- Robustness: Implements division-by-zero guards and COALESCE for missing salary data.
- Optimization: Aggregates datasets prior to joining to reduce the join-space cardinality.
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
        -- Total Bases Calculation: H + 2B + (2 * 3B) + (3 * HR)
        SUM(H + "2B" + (2 * "3B") + (3 * HR)) AS total_bases
    FROM 
        curated.Batting
    GROUP BY 
        1, 2 -- Uses ordinal grouping for cleaner syntax
),

team_salaries AS (
    SELECT 
        teamID,
        yearID,
        SUM(salary) AS total_payroll
    FROM 
        curated.Salaries
    GROUP BY 
        1, 2
)

SELECT 
    b.teamID,
    b.yearID,
    COALESCE(s.total_payroll, 0) AS total_payroll,
    b.total_ab AS AB,
    b.total_hr AS HR,
    
    -- Performance Metrics
    CASE 
        WHEN b.total_ab > 0 THEN ROUND(CAST(b.total_h AS FLOAT) / b.total_ab, 3) 
        ELSE 0 
    END AS batting_average,
    
    CASE 
        WHEN b.total_ab > 0 THEN ROUND(CAST(b.total_bases AS FLOAT) / b.total_ab, 3) 
        ELSE 0 
    END AS slugging_percentage,
    
    -- Financial ROI: HR per Million Dollars spent
    CASE 
        WHEN s.total_payroll > 0 THEN ROUND(b.total_hr / (s.total_payroll / 1000000.0), 2) 
        ELSE 0 
    END AS hr_per_million
FROM 
    team_batting b
LEFT JOIN 
    team_salaries s ON b.teamID = s.teamID AND b.yearID = s.yearID
ORDER BY 
    yearID DESC, 
    teamID ASC;