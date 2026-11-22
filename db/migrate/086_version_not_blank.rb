class VersionNotBlank < ActiveRecord::Migration[7.2]
  # Upstream migration 073_version_not_blank (leihs_database 44db05b),
  # renumbered because 073 is taken in this fork. The new inventory refuses
  # a blank version; the database does too: blank versions become NULL and
  # a check constraint keeps them out.
  #
  # The collision check differs from upstream: here the name of a model
  # carries its manufacturer (079_manufacturer_in_model_name), so it compares
  # the names the models will have once blank versions are NULL.

  NEW_NAME = lambda do |t|
    <<~SQL
      CASE WHEN NULLIF(btrim(#{t}.manufacturer::text), '') IS NULL THEN ''
           ELSE btrim(#{t}.manufacturer::text) || ' '
      END
      || CASE WHEN #{t}.version IS NULL OR #{t}.version ~ '^\\s*$' THEN #{t}.product::text
              ELSE #{t}.product::text || ' ' || #{t}.version::text
         END
    SQL
  end

  def up
    collisions = select_all(<<~SQL)
      SELECT m.id, m.product FROM models m
      WHERE m.version ~ '^\\s*$'
        AND EXISTS (SELECT 1 FROM models o
                    WHERE o.id <> m.id
                      AND (#{NEW_NAME.call('o')}) = (#{NEW_NAME.call('m')}))
    SQL

    if collisions.any?
      list = collisions.map { |row| "#{row["id"]} (#{row["product"]})" }.join("\n  ")
      raise <<~MSG
        Models with blank version clash with a model of the same name and no version.
        Merge or rename them manually before running this migration:
          #{list}
      MSG
    end

    execute <<~'SQL'
      UPDATE models SET version = NULL WHERE version ~ '^\s*$';
      UPDATE options SET version = NULL WHERE version ~ '^\s*$';

      ALTER TABLE models
      ADD CONSTRAINT models_version_not_blank
      CHECK (version IS NULL OR version !~ '^\s*$');

      ALTER TABLE options
      ADD CONSTRAINT options_version_not_blank
      CHECK (version IS NULL OR version !~ '^\s*$');
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE models DROP CONSTRAINT models_version_not_blank;
      ALTER TABLE options DROP CONSTRAINT options_version_not_blank;
    SQL
  end
end
