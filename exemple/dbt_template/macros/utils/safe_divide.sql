{% macro safe_divide(numerator, denominator, default=0) %}
{#
    Division sécurisée qui évite les erreurs de division par zéro.
    
    Arguments:
        numerator: Numérateur
        denominator: Dénominateur
        default: Valeur par défaut si division impossible (défaut: 0)
    
    Exemple d'utilisation:
        {{ safe_divide('revenue', 'orders') }}
        {{ safe_divide('total', 'count', null) }}
    
    Résultat:
        CASE 
            WHEN denominator = 0 OR denominator IS NULL THEN default
            ELSE numerator / denominator 
        END
#}
    CASE 
        WHEN {{ denominator }} = 0 OR {{ denominator }} IS NULL THEN {{ default }}
        ELSE {{ numerator }} / {{ denominator }}
    END
{% endmacro %}

