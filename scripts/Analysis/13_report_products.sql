/*
============================================================================================
Product Repport
============================================================================================
Purpose:
	- This report consolidates key Repport metrics and behaviors

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates product-level-metrics:
		- total orders
		- total sales
		- total quantity sold
		- total cusotmers (unique) 
		- life span (in months)
	4. Calculates  valuable KPIs:
		- recency (month since last sale)
		- average order revenue (AOR) 
		- average monthly spend
*/
CREATE VIEW gold.report_products AS

WITH base_query AS (
/*--------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from fact_sales and dim_products
--------------------------------------------------------------------------------------*/
SELECT 
	f.order_number,
	f.order_date,
	f.customer_key,
	f.sales_amount,
	f.quantity,
	p.product_key,
	p.product_name,
	p.category,
	p.sub_category,
	p.cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
),

product_aggregations AS (
/*--------------------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the customer level
--------------------------------------------------------------------------------------*/
SELECT 
	product_key,
	product_name,
	category,
	sub_category,
	cost,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span,
	MAX(order_date) AS last_order_date,
	COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantities,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)), 1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	product_name,
	category,
	sub_category,
	cost
)

/*--------------------------------------------------------------------------------------
3) Final query: Combines all products results into one output
--------------------------------------------------------------------------------------*/

SELECT
	product_key,
	product_name,
	category,
	sub_category,
	cost,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency_in_month,
	CASE
		WHEN total_sales > 50000 THEN 'High-Perfomer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	life_span,
	total_orders,
	total_customers,
	total_sales,
	total_quantities,
	avg_selling_price,
	-- Avreage Order Revemue (AOR)
	CASE WHEN total_orders = 0 THEN 0
		 ELSE total_sales / total_orders
	END	AS avg_order_revenue,

	-- Avergae monthly Revenue
	CASE WHEN life_span = 0 THEN total_sales
		 ELSE total_sales / life_span
	END	AS avg_monthly_revenue

FROM product_aggregations
