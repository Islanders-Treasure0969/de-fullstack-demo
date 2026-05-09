{#
    Override dbt's default schema-naming behaviour.

    Default: when a model has `+schema: bronze`, dbt creates the table at
        <target_schema>_<custom_schema>  →  main_bronze

    Override: use the custom schema name verbatim, so models declared as
    `+schema: bronze` land in `bronze.*`. This matches what Streamlit and
    case-study SQL examples reference.

    See https://docs.getdbt.com/docs/build/custom-schemas
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
