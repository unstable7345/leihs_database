class ManufacturerInModelName < ActiveRecord::Migration[7.2]
  # The name of a model shows its manufacturer too ("Audient ASP-800"), so
  # that a manufacturer typed into the product ("AKG AKG D112") stands out.
  # `name` is a generated column: it is dropped and added again with the new
  # expression, together with the view and the index that depend on it.

  NAME_WITH_MANUFACTURER = <<~SQL
    CASE WHEN NULLIF(btrim(manufacturer::text), '') IS NULL THEN ''
         ELSE btrim(manufacturer::text) || ' '
    END
    || CASE WHEN version IS NULL THEN product::text
            ELSE product::text || ' ' || version::text
       END
  SQL

  NAME_WITHOUT_MANUFACTURER = <<~SQL
    CASE WHEN version IS NULL THEN product::text
         ELSE product::text || ' ' || version::text
    END
  SQL

  INVENTORY_VIEW = <<~SQL
    CREATE VIEW inventory AS
     SELECT models.id,
        models.product,
        models.version,
        models.name,
            CASE models.type
                WHEN 'Software'::text THEN 'Software'::text
                WHEN 'Model'::text THEN
                CASE
                    WHEN models.is_package THEN 'Package'::text
                    ELSE 'Model'::text
                END
                ELSE NULL::text
            END AS type,
        'models'::text AS origin_table,
        models.manufacturer,
        NULL::character varying AS inventory_code,
        NULL::numeric AS price,
        NULL::uuid AS inventory_pool_id,
        models.cover_image_id,
        models.created_at,
        models.updated_at
       FROM models
    UNION
     SELECT options.id,
        options.product,
        options.version,
        options.name,
        'Option'::text AS type,
        'options'::text AS origin_table,
        options.manufacturer,
        options.inventory_code,
        options.price,
        options.inventory_pool_id,
        NULL::uuid AS cover_image_id,
        options.created_at,
        options.updated_at
       FROM options;
  SQL

  def up
    replace_name(NAME_WITH_MANUFACTURER)
  end

  def down
    replace_name(NAME_WITHOUT_MANUFACTURER)
  end

  private

  def replace_name(expression)
    execute <<~SQL
      DROP VIEW inventory;
      DROP INDEX unique_model_name_idx;
      ALTER TABLE models DROP COLUMN name;
      ALTER TABLE models ADD COLUMN name text GENERATED ALWAYS AS (#{expression}) STORED;
      CREATE UNIQUE INDEX unique_model_name_idx ON models USING btree (name);
      #{INVENTORY_VIEW}
    SQL
  end
end
