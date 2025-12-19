{{
    config(
        materialized='table',
        tags=['marts', 'core', 'daily']
    )
}}

/*
==========================================================================
Model: fct_orders
Description: Table de faits des commandes
Layer: Marts
Grain: Une ligne par commande

Usage:
- Analyse des ventes
- Suivi des commandes
- KPIs business
==========================================================================
*/

WITH orders AS (
    SELECT * FROM {{ ref('stg_ecommerce__orders') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_ecommerce__customers') }}
),

products AS (
    SELECT * FROM {{ ref('stg_ecommerce__products') }}
),

order_status AS (
    SELECT * FROM {{ ref('order_status_mapping') }}
),

payment_methods AS (
    SELECT * FROM {{ ref('payment_methods') }}
),

countries AS (
    SELECT * FROM {{ ref('country_codes') }}
),

-- Calcul du numéro de commande par client
orders_with_rank AS (
    SELECT
        o.*,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.ordered_at
        ) AS customer_order_number
    FROM orders o
),

final AS (
    SELECT
        -- =====================================================================
        -- Clés
        -- =====================================================================
        o.order_id,
        o.customer_id,
        o.product_id,
        
        -- =====================================================================
        -- Attributs client (dénormalisés pour faciliter les analyses)
        -- =====================================================================
        c.full_name AS customer_name,
        c.email AS customer_email,
        c.country_code AS customer_country_code,
        co.country_name AS customer_country_name,
        co.region AS customer_region,
        
        -- =====================================================================
        -- Attributs produit (dénormalisés)
        -- =====================================================================
        p.product_name,
        p.product_category,
        p.price_amount AS product_unit_price,
        
        -- =====================================================================
        -- Attributs de la commande
        -- =====================================================================
        o.quantity,
        o.order_total_cents,
        o.order_total,
        
        -- Statut enrichi
        o.status_code,
        os.status_name,
        os.status_category,
        os.is_final AS is_status_final,
        
        -- Paiement enrichi
        o.payment_method_code,
        pm.payment_method_name,
        pm.payment_category AS payment_method_category,
        
        -- =====================================================================
        -- Dates et timestamps
        -- =====================================================================
        o.ordered_at,
        o.order_date,
        o.shipped_at,
        o.delivered_at,
        
        -- Calcul des délais en heures
        CASE 
            WHEN o.shipped_at IS NOT NULL 
            THEN DATEDIFF('hour', o.ordered_at, o.shipped_at) 
        END AS hours_to_ship,
        
        CASE 
            WHEN o.shipped_at IS NOT NULL AND o.delivered_at IS NOT NULL 
            THEN DATEDIFF('hour', o.shipped_at, o.delivered_at) 
        END AS hours_to_deliver,
        
        CASE 
            WHEN o.delivered_at IS NOT NULL 
            THEN DATEDIFF('hour', o.ordered_at, o.delivered_at) 
        END AS total_fulfillment_hours,
        
        -- =====================================================================
        -- Flags
        -- =====================================================================
        o.is_shipped,
        o.is_delivered,
        
        -- Premier achat du client ?
        CASE 
            WHEN o.customer_order_number = 1 THEN TRUE 
            ELSE FALSE 
        END AS is_first_order,
        
        -- Commande complétée ?
        CASE 
            WHEN os.status_category = 'Completed' THEN TRUE 
            ELSE FALSE 
        END AS is_completed,
        
        -- Commande annulée ?
        CASE 
            WHEN os.status_category = 'Cancelled' THEN TRUE 
            ELSE FALSE 
        END AS is_cancelled,
        
        -- =====================================================================
        -- Métriques pour agrégation
        -- =====================================================================
        o.customer_order_number,
        
        -- Revenu net (0 si annulée)
        CASE 
            WHEN os.status_category = 'Completed' THEN o.order_total 
            ELSE 0 
        END AS net_revenue
        
    FROM orders_with_rank o
    -- Jointures pour enrichissement
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN products p
        ON o.product_id = p.product_id
    LEFT JOIN order_status os
        ON o.status_code = os.status_code
    LEFT JOIN payment_methods pm
        ON o.payment_method_code = pm.payment_method_code
    LEFT JOIN countries co
        ON c.country_code = co.country_code
)

SELECT * FROM final

