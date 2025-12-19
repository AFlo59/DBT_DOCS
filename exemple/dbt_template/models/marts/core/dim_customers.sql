{{
    config(
        materialized='table',
        tags=['marts', 'core', 'daily']
    )
}}

/*
==========================================================================
Model: dim_customers
Description: Dimension des clients avec métriques agrégées
Layer: Marts
Grain: Une ligne par client

Usage:
- Analyse des segments clients
- Calcul de la valeur vie client (LTV)
- Segmentation marketing
==========================================================================
*/

WITH customers AS (
    -- Données clients staging
    SELECT * FROM {{ ref('stg_ecommerce__customers') }}
),

orders AS (
    -- Données commandes staging
    SELECT * FROM {{ ref('stg_ecommerce__orders') }}
),

order_status AS (
    -- Mapping des statuts
    SELECT * FROM {{ ref('order_status_mapping') }}
),

countries AS (
    -- Référentiel pays
    SELECT * FROM {{ ref('country_codes') }}
),

-- Calcul des métriques par client
customer_order_metrics AS (
    SELECT
        o.customer_id,
        
        -- Compteurs
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN os.status_category = 'Completed' THEN o.order_id END) AS completed_orders,
        COUNT(DISTINCT CASE WHEN os.status_category = 'Cancelled' THEN o.order_id END) AS cancelled_orders,
        
        -- Montants
        SUM(CASE WHEN os.status_category = 'Completed' THEN o.order_total ELSE 0 END) AS lifetime_value,
        AVG(CASE WHEN os.status_category = 'Completed' THEN o.order_total END) AS average_order_value,
        
        -- Dates
        MIN(o.ordered_at) AS first_order_at,
        MAX(o.ordered_at) AS last_order_at,
        
        -- Durée de vie client en jours
        DATEDIFF('day', MIN(o.ordered_at), MAX(o.ordered_at)) AS customer_lifespan_days
        
    FROM orders o
    LEFT JOIN order_status os
        ON o.status_code = os.status_code
    GROUP BY 1
),

-- Construction de la dimension finale
final AS (
    SELECT
        -- =====================================================================
        -- Clé primaire
        -- =====================================================================
        c.customer_id,
        
        -- =====================================================================
        -- Attributs descriptifs
        -- =====================================================================
        c.first_name,
        c.last_name,
        c.full_name,
        c.email,
        
        -- Géographie
        c.country_code,
        co.country_name,
        co.region AS country_region,
        co.currency_code AS country_currency,
        
        -- Statut
        c.is_active,
        c.created_at AS customer_since,
        
        -- =====================================================================
        -- Métriques agrégées (dénormalisation pour performance)
        -- =====================================================================
        COALESCE(m.total_orders, 0) AS total_orders,
        COALESCE(m.completed_orders, 0) AS completed_orders,
        COALESCE(m.cancelled_orders, 0) AS cancelled_orders,
        COALESCE(m.lifetime_value, 0) AS lifetime_value,
        m.average_order_value,
        m.first_order_at,
        m.last_order_at,
        m.customer_lifespan_days,
        
        -- =====================================================================
        -- Segmentation
        -- =====================================================================
        CASE
            WHEN m.lifetime_value >= 500 THEN 'VIP'
            WHEN m.lifetime_value >= 200 THEN 'Regular'
            WHEN m.lifetime_value >= 50 THEN 'Occasional'
            WHEN m.lifetime_value > 0 THEN 'New'
            ELSE 'Prospect'
        END AS customer_segment,
        
        -- Statut d'engagement basé sur la dernière commande
        CASE
            WHEN m.last_order_at >= DATEADD('day', -30, CURRENT_DATE()) THEN 'Active'
            WHEN m.last_order_at >= DATEADD('day', -90, CURRENT_DATE()) THEN 'At Risk'
            WHEN m.last_order_at >= DATEADD('day', -180, CURRENT_DATE()) THEN 'Dormant'
            WHEN m.last_order_at IS NOT NULL THEN 'Churned'
            ELSE 'Never Ordered'
        END AS engagement_status,
        
        -- Flag: client à forte valeur
        CASE 
            WHEN m.lifetime_value >= 500 THEN TRUE 
            ELSE FALSE 
        END AS is_high_value,
        
        -- Flag: premier achat = inscription (même jour)
        CASE 
            WHEN DATE(c.created_at) = DATE(m.first_order_at) THEN TRUE 
            ELSE FALSE 
        END AS is_first_order_same_day
        
    FROM customers c
    LEFT JOIN customer_order_metrics m
        ON c.customer_id = m.customer_id
    LEFT JOIN countries co
        ON c.country_code = co.country_code
)

SELECT * FROM final

