/*
==========================================================================
Test singulier: Vérifier que le revenu net est toujours >= 0

Description:
    Ce test vérifie que la colonne net_revenue dans fct_orders
    ne contient jamais de valeurs négatives.
    
    Un revenu négatif pourrait indiquer:
    - Une erreur de calcul
    - Un problème avec les remboursements
    - Des données corrompues

Comportement:
    - Le test ÉCHOUE si des lignes sont retournées
    - Le test PASSE si aucune ligne n'est retournée
==========================================================================
*/

SELECT
    order_id,
    customer_id,
    net_revenue,
    status_code
FROM {{ ref('fct_orders') }}
WHERE net_revenue < 0

