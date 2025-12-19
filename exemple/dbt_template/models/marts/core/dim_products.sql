{{
    config(
        materialized='table',
        tags=['marts', 'core', 'daily']
    )
}}

/*
==========================================================================
Model: dim_products
Description: Dimension des produits avec métriques de vente
Layer: Marts
Grain: Une ligne par produit

Usage:
- Analyse du catalogue produits
- Performance des ventes par produit
- Gestion des stocks
==========================================================================
*/

WITH products AS (
    SELECT * FROM {{ ref('stg_ecommerce__products') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_ecommerce__orders') }}
),

order_status AS (
    SELECT * FROM {{ ref('order_status_mapping') }}
),

-- Métriques de vente par produit
product_sales_metrics AS (
    SELECT
        o.product_id,
        
        -- Volume
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.quantity) AS total_quantity_sold,
        
        -- Revenus (commandes complétées uniquement)
        SUM(CASE WHEN os.status_category = 'Completed' THEN o.order_total ELSE 0 END) AS total_revenue,
        AVG(CASE WHEN os.status_category = 'Completed' THEN o.order_total END) AS avg_order_value,
        
        -- Clients uniques
        COUNT(DISTINCT o.customer_id) AS unique_customers,
        
        -- Temporel
        MIN(o.ordered_at) AS first_sold_at,
        MAX(o.ordered_at) AS last_sold_at
        
    FROM orders o
    LEFT JOIN order_status os
        ON o.status_code = os.status_code
    GROUP BY 1
),

final AS (
    SELECT
        -- =====================================================================
        -- Clé primaire
        -- =====================================================================
        p.product_id,
        
        -- =====================================================================
        -- Attributs du produit
        -- =====================================================================
        p.product_name,
        p.product_category,
        p.price_cents,
        p.price_amount,
        p.currency_code,
        p.is_available,
        
        -- =====================================================================
        -- Métriques de vente (dénormalisation)
        -- =====================================================================
        COALESCE(m.total_orders, 0) AS total_orders,
        COALESCE(m.total_quantity_sold, 0) AS total_quantity_sold,
        COALESCE(m.total_revenue, 0) AS total_revenue,
        m.avg_order_value,
        COALESCE(m.unique_customers, 0) AS unique_customers,
        m.first_sold_at,
        m.last_sold_at,
        
        -- =====================================================================
        -- Segmentation produit
        -- =====================================================================
        CASE
            WHEN m.total_revenue >= 100 THEN 'Best Seller'
            WHEN m.total_revenue >= 50 THEN 'Popular'
            WHEN m.total_revenue > 0 THEN 'Regular'
            ELSE 'New/No Sales'
        END AS product_performance_tier,
        
        -- Gamme de prix
        CASE
            WHEN p.price_amount >= 100 THEN 'Premium'
            WHEN p.price_amount >= 50 THEN 'Mid-Range'
            ELSE 'Budget'
        END AS price_tier,
        
        -- Flags
        CASE 
            WHEN m.total_orders >= 5 THEN TRUE 
            ELSE FALSE 
        END AS is_popular
        
    FROM products p
    LEFT JOIN product_sales_metrics m
        ON p.product_id = m.product_id
)

SELECT * FROM final

