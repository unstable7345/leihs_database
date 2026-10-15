class Tags < ActiveRecord::Migration[7.2]
  # Tags of an inventory pool ("Etiquetado", "Revisar", ...) that its staff
  # put on items, to show them in the inventory list and filter by them.
  # Only new tables: nothing existing changes.

  def up
    execute <<~SQL
      CREATE TABLE tags (
        id uuid DEFAULT uuid_generate_v4() NOT NULL PRIMARY KEY,
        inventory_pool_id uuid NOT NULL REFERENCES inventory_pools(id) ON DELETE CASCADE,
        name text NOT NULL,
        color text NOT NULL DEFAULT '#e4572e',
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        updated_at timestamp without time zone DEFAULT now() NOT NULL,
        CONSTRAINT tags_name_not_blank CHECK (name !~ '^\\s*$'),
        CONSTRAINT tags_color_is_hex CHECK (color ~ '^#[0-9a-fA-F]{6}$')
      );

      CREATE UNIQUE INDEX tags_unique_name_per_pool
        ON tags (inventory_pool_id, lower(name));

      CREATE TABLE items_tags (
        item_id uuid NOT NULL REFERENCES items(id) ON DELETE CASCADE,
        tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (item_id, tag_id)
      );

      CREATE INDEX index_items_tags_on_tag_id ON items_tags (tag_id);
    SQL
  end

  def down
    execute <<~SQL
      DROP TABLE items_tags;
      DROP TABLE tags;
    SQL
  end
end
