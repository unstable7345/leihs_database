class TrimMailTemplates < ActiveRecord::Migration[7.2]
  # The Markdown mails to customers (087) keep only what they need: no
  # signature and no pool footer (name, contact, opening hours, holidays,
  # description), just the line saying the mail is automatic. Templates
  # whose text was changed since 087 keep it.

  FOOTER = <<~LIQUID.chomp
    {{ email_signature }}

    ---

    **{{ inventory_pool.name }}**
    {{ inventory_pool.contact }}

    ### Opening hours
    {{ inventory_pool.workdays }}
    {% if inventory_pool.holidays and inventory_pool.holidays != "" %}
    ### Closed
    {{ inventory_pool.holidays }}
    {% endif %}
    {{ inventory_pool.description }}

    This is an automatic message from leihs.
  LIQUID

  SHORT_FOOTER = <<~LIQUID.chomp
    ---

    This is an automatic message from leihs.
  LIQUID

  def up
    execute <<~SQL
      UPDATE mail_templates
      SET body = replace(body, #{quote(FOOTER)}, #{quote(SHORT_FOOTER)}),
          updated_at = now()
      WHERE format = 'markdown'
        AND strpos(body, #{quote(FOOTER)}) > 0;
    SQL
  end

  def down
    execute <<~SQL
      UPDATE mail_templates
      SET body = replace(body, #{quote(SHORT_FOOTER)}, #{quote(FOOTER)}),
          updated_at = now()
      WHERE format = 'markdown'
        AND name <> 'received'
        AND strpos(body, #{quote(SHORT_FOOTER)}) > 0;
    SQL
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
