{{
    config(
        materialized='view',
        tags=['staging', 'ecommerce', 'daily']
    )
}}

/*
==========================================================================
Model: stg_ecommerce__products
Description: Staging des produits e-commerce
Layer: Staging
Grain: Une ligne par produit

Transformations:
- Renommage des colonnes
- Conversion centimes → dollars
- Nettoyage des textes
==========================================================================
*/

WITH source AS (
    SELECT * FROM {{ source('ecommerce', 'products') }}
),

renamed AS (
    SELECT
        -- =====================================================================
        -- Primary Key
        -- =====================================================================
        product_id,
        
        -- =====================================================================
        -- Attributs du produit
        -- =====================================================================
        TRIM(product_name) AS product_name,
        TRIM(category) AS product_category,
        
        -- Prix en centimes (original)
        price_cents,
        
        -- Prix converti en dollars (ou devise principale)
        ROUND(price_cents / 100.0, 2) AS price_amount,
        
        -- Devise
        UPPER(TRIM(currency_code)) AS currency_code,
        
        -- =====================================================================
        -- Flags
        -- =====================================================================
        COALESCE(is_available, TRUE) AS is_available
        
    FROM source
)

SELECT * FROM renamed
WHERE product_id IS NOT NULL

