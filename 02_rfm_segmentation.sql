WITH rfm_base AS (
    SELECT
        customer_id,
        DATE_DIFF('day', MAX(order_date), CAST('2026-03-01' AS DATE)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency_orders,
        SUM(order_amount) AS monetary_total
    FROM orders
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency_orders,
        monetary_total,
        -- fewer days since last order is better, so the quintile gets flipped
        6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_total ASC) AS m_score
    FROM rfm_base
),
rfm_segmented AS (
    SELECT
        customer_id,
        recency_days,
        frequency_orders,
        monetary_total,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score) / 3.0 AS rfm_average,
        -- these thresholds are a starting point, could be tuned per business
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Inactive / New'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk / Churning'
            ELSE 'Lost / Hibernating'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency_orders), 1) AS avg_orders,
    ROUND(AVG(monetary_total), 2) AS avg_customer_spend,
    ROUND(SUM(monetary_total), 2) AS total_segment_revenue
FROM rfm_segmented
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;