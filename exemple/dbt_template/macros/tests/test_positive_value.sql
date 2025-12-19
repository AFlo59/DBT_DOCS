/*
    Test générique personnalisé: vérifie que les valeurs sont positives.
    
    Arguments:
        model: Le modèle à tester
        column_name: La colonne à vérifier
        allow_zero: Autoriser les zéros (défaut: true)
    
    Exemple d'utilisation dans schema.yml:
        columns:
          - name: amount
            tests:
              - positive_value
              - positive_value:
                  allow_zero: false
*/

{% test positive_value(model, column_name, allow_zero=true) %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  {% if allow_zero %}
  AND {{ column_name }} < 0
  {% else %}
  AND {{ column_name }} <= 0
  {% endif %}

{% endtest %}

