/*
    Macro: generate_schema_name
    Macro pour générer le nom du schéma.
    
    Comportement par environnement:
    - prod: Utilise le custom_schema tel quel (staging, analytics, etc.)
    - dev/rec: Préfixe avec le schéma par défaut (dbt_user_staging, etc.)
    
    Cette macro override le comportement par défaut de DBT.
*/

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    
    {%- if target.name == 'prod' -%}
        {# En production, on utilise le nom de schéma défini sans préfixe #}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            {{ custom_schema_name | trim }}
        {%- endif -%}
        
    {%- else -%}
        {# En dev/staging, on préfixe avec le schéma utilisateur #}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            {{ default_schema }}_{{ custom_schema_name | trim }}
        {%- endif -%}
        
    {%- endif -%}

{%- endmacro %}

