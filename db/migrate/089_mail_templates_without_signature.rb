class MailTemplatesWithoutSignature < ActiveRecord::Migration[7.2]
  # No mail ends with the signature any more: the line holding
  # {{ email_signature }} (and the empty lines before it) is taken out of
  # every mail template, in every language, also of the ones a pool changed.
  # The bodies before this change are kept in mail_templates_pre_089 for
  # `down`.

  SIGNATURE = '\n*[ \t]*\{\{-?[ \t]*email_signature[ \t]*-?\}\}[ \t]*'

  def up
    execute <<~SQL
      CREATE TABLE mail_templates_pre_089 AS
        SELECT id, body FROM mail_templates
        WHERE body ~ '#{SIGNATURE}';
    SQL

    execute <<~SQL
      UPDATE mail_templates
      SET body = regexp_replace(body, '#{SIGNATURE}', '', 'g'),
          updated_at = now()
      WHERE id IN (SELECT id FROM mail_templates_pre_089);
    SQL
  end

  def down
    execute <<~SQL
      UPDATE mail_templates
      SET body = old.body, updated_at = now()
      FROM mail_templates_pre_089 AS old
      WHERE mail_templates.id = old.id;
    SQL
    execute 'DROP TABLE mail_templates_pre_089;'
  end
end
