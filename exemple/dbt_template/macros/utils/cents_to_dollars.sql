{% macro cents_to_dollars(column_name, precision=2) %}
{#
    Convertit un montant en centimes vers dollars (ou devise principale).
    
    Arguments:
        column_name: Nom de la colonne contenant les centimes
        precision: Nombre de décimales (défaut: 2)
    
    Exemple d'utilisation:
        {{ cents_to_dollars('price_cents') }}
        {{ cents_to_dollars('amount', 4) }}
    
    Résultat:
        ROUND(price_cents / 100.0, 2)
#}
    ROUND({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}

