WITH customer_cohort AS (
    -- a customer's cohort = the month of their very first order
    SELECT
        customer_id,
        MIN(DATE_TRUNC('month', order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_orders AS (
    -- tag every order with the customer's cohort month
    SELECT
        o.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', o.order_date) AS order_month
    FROM orders o
    JOIN customer_cohort c ON o.customer_id = c.customer_id
),
cohort_index AS (
    -- how many months out from signup is this order? 0 = the signup month itself
    SELECT
        cohort_month,
        order_month,
        (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12 +
        (EXTRACT(MONTH FROM order_month) - EXTRACT(MONTH FROM cohort_month)) AS period_index,
        customer_id
    FROM customer_orders
),
cohort_counts AS (
    SELECT
        cohort_month,
        period_index,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_index
    GROUP BY cohort_month, period_index
)
SELECT
    CAST(cohort_month AS VARCHAR) AS cohort_month,
    period_index,
    active_customers,
    -- retention rate vs. period 0 (the cohort's first month)
    ROUND(
        CAST(active_customers AS FLOAT) /
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month ORDER BY period_index
        ) * 100, 2
    ) AS retention_rate
FROM cohort_counts
ORDER BY cohort_month, period_index;