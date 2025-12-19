{% macro limit_in_dev(default_limit=10000) %}
{#
    Ajoute une clause LIMIT uniquement en environnement de développement.
    Utile pour accélérer les tests locaux.
    
    Arguments:
        default_limit: Nombre de lignes à retourner en dev (défaut: 10000)
    
    Exemple d'utilisation:
        SELECT * FROM ma_table
        {{ limit_in_dev() }}
    
    Comportement:
        - En dev: ajoute "LIMIT 10000"
        - En prod/rec: n'ajoute rien
#}

    {%- if target.name == 'dev' -%}
        LIMIT {{ var('dev_row_limit', default_limit) }}
    {%- endif -%}

{% endmacro %}

