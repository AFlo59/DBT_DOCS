{{
    config(
        materialized='view',
        tags=['staging', 'ecommerce', 'daily']
    )
}}

/*
==========================================================================
Model: stg_ecommerce__customers
Description: Staging des clients e-commerce
Layer: Staging
Grain: Une ligne par client

Transformations:
- Renommage des colonnes selon les conventions
- Nettoyage des données textuelles (trim, lower)
- Casting des types
- Création du nom complet
==========================================================================
*/

WITH source AS (
    -- Référence à la source e-commerce
    SELECT * FROM {{ source('ecommerce', 'customers') }}
),

renamed AS (
    SELECT
        -- =====================================================================
        -- Primary Key
        -- =====================================================================
        customer_id,
        
        -- =====================================================================
        -- Attributs du client
        -- =====================================================================
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        CONCAT(TRIM(first_name), ' ', TRIM(last_name)) AS full_name,
        
        -- Email nettoyé (lowercase, trim)
        LOWER(TRIM(email)) AS email,
        
        -- Code pays
        UPPER(TRIM(country_code)) AS country_code,
        
        -- =====================================================================
        -- Flags
        -- =====================================================================
        COALESCE(is_active, FALSE) AS is_active,
        
        -- =====================================================================
        -- Dates
        -- =====================================================================
        CAST(created_at AS TIMESTAMP) AS created_at
        
    FROM source
)

SELECT * FROM renamed
-- Filtrage des données invalides
WHERE customer_id IS NOT NULL

