{{
    config(
        materialized='view',
        tags=['staging', 'ecommerce', 'daily']
    )
}}

/*
==========================================================================
Model: stg_ecommerce__orders
Description: Staging des commandes e-commerce
Layer: Staging
Grain: Une ligne par commande

Transformations:
- Renommage des colonnes
- Conversion centimes → dollars
- Casting des dates
- Nettoyage des codes
==========================================================================
*/

WITH source AS (
    SELECT * FROM {{ source('ecommerce', 'orders') }}
),

renamed AS (
    SELECT
        -- =====================================================================
        -- Primary Key
        -- =====================================================================
        order_id,
        
        -- =====================================================================
        -- Foreign Keys
        -- =====================================================================
        customer_id,
        product_id,
        
        -- =====================================================================
        -- Attributs de la commande
        -- =====================================================================
        quantity,
        
        -- Codes nettoyés
        UPPER(TRIM(status_code)) AS status_code,
        UPPER(TRIM(payment_method_code)) AS payment_method_code,
        
        -- Montants
        order_total_cents,
        ROUND(order_total_cents / 100.0, 2) AS order_total,
        
        -- =====================================================================
        -- Dates
        -- =====================================================================
        CAST(ordered_at AS TIMESTAMP) AS ordered_at,
        DATE(ordered_at) AS order_date,
        
        CAST(shipped_at AS TIMESTAMP) AS shipped_at,
        CAST(delivered_at AS TIMESTAMP) AS delivered_at,
        
        -- =====================================================================
        -- Flags calculés
        -- =====================================================================
        CASE 
            WHEN shipped_at IS NOT NULL THEN TRUE 
            ELSE FALSE 
        END AS is_shipped,
        
        CASE 
            WHEN delivered_at IS NOT NULL THEN TRUE 
            ELSE FALSE 
        END AS is_delivered
        
    FROM source
)

SELECT * FROM renamed
WHERE order_id IS NOT NULL
  AND ordered_at IS NOT NULL

