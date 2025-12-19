/*
==========================================================================
Test singulier: Vérifier qu'il n'y a pas de commandes orphelines

Description:
    Ce test vérifie que toutes les commandes dans fct_orders ont un client
    valide dans dim_customers.
    
    Une commande orpheline pourrait indiquer:
    - Un problème de données source
    - Un client supprimé sans cascade
    - Un problème de timing dans le pipeline

Comportement:
    - Le test ÉCHOUE si des lignes sont retournées
    - Le test PASSE si aucune ligne n'est retournée
==========================================================================
*/

WITH orders AS (
    SELECT 
        order_id,
        customer_id
    FROM {{ ref('fct_orders') }}
),

customers AS (
    SELECT customer_id
    FROM {{ ref('dim_customers') }}
),

-- Trouver les commandes sans client correspondant
orphan_orders AS (
    SELECT
        o.order_id,
        o.customer_id
    FROM orders o
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL
)

SELECT * FROM orphan_orders

