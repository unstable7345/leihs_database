class MarkdownMailTemplates < ActiveRecord::Migration[7.2]
  # Mails can be Markdown: the mail service sends them as HTML in one layout,
  # with a plain text alternative. emails.format says which kind a mail is
  # ('text' or 'markdown'); the senders copy it from the mail template.
  #
  # The English templates (en-GB, en-US) are rewritten in Markdown. Pool
  # templates change only while they still hold the text of the template
  # they were copied from; customized ones stay as they are (plain text).
  # The rows this changes are kept in mail_templates_pre_087 for `down`.

  DATE = "date: '%a %d %b'"

  ITEMS = <<~LIQUID.chomp
    {% for l in reservations %}
    - **{{ l.quantity }} × {{ l.model_name }}** · {% if l.time_slot %}{{ l.start_date | #{DATE} }}, {{ l.time_slot }}{% elsif l.start_date == l.end_date %}{{ l.start_date | #{DATE} }}{% else %}{{ l.start_date | #{DATE} }} – {{ l.end_date | #{DATE} }}{% endif %}{% endfor %}
  LIQUID

  RETURN_ITEMS = <<~LIQUID.chomp
    {% for l in reservations %}
    - **{{ l.quantity }} × {{ l.model_name }}**{% if l.item_inventory_code %} · {{ l.item_inventory_code }}{% endif %}{% if l.time_slot %} · {{ l.time_slot }}{% endif %}{% endfor %}
  LIQUID

  POOL_FOOTER = <<~LIQUID.chomp
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

  COMMENT = <<~LIQUID.chomp
    {% if comment and comment != "" %}
    > {{ comment }}
    {% endif %}
  LIQUID

  TEMPLATES = {
    'submitted' => {
      subject: "We've received your order",
      body: <<~LIQUID
        # We've received your order

        Hi {{ user.name }},

        Your order at {{ inventory_pool.name }} is waiting for approval. You'll get another email as soon as the team has reviewed it.
        #{ITEMS}

        ### Purpose
        {{ purpose }}

        [View your order]({{ rental_url }})

        {{ email_signature }}

        #{POOL_FOOTER}
      LIQUID
    },
    'approved' => {
      subject: 'Your order is confirmed',
      body: <<~LIQUID
        # Your order is confirmed

        Hi {{ user.name }},

        {{ inventory_pool.name }} has approved your order. Pick up the items at the start of your reservation.
        #{ITEMS}

        #{COMMENT}

        [View your order]({{ rental_url }})

        {{ email_signature }}

        #{POOL_FOOTER}
      LIQUID
    },
    'rejected' => {
      subject: "Your order wasn't approved",
      body: <<~LIQUID
        # Your order wasn't approved

        Hi {{ user.name }},

        {{ inventory_pool.name }} couldn't approve your order for these items:
        #{ITEMS}

        #{COMMENT}

        If you have any questions, reply to this email.

        {{ email_signature }}

        #{POOL_FOOTER}
      LIQUID
    },
    'received' => {
      subject: '[leihs] New order',
      body: <<~LIQUID
        # {% if approved %}New order, approved automatically{% else %}New order to review{% endif %}

        {{ user.name }} placed an order at {{ inventory_pool.name }}.
        #{ITEMS}

        ### Purpose
        {{ purpose }}

        {% if approved %}It was approved automatically, as an hourly reservation within the same day. There's nothing to approve: have the items ready for pick up.{% else %}It's waiting for your approval. The person who placed it knows it isn't valid until it's approved.{% endif %}

        [Open the order]({{ order_url }})

        ---

        This is an automatic message from leihs.
      LIQUID
    },
    'reminder' => {
      subject: 'Some items are overdue',
      body: <<~LIQUID
        # Some items are overdue

        Hi {{ user.name }},

        {{ quantity }} item(s) from {{ inventory_pool.name }} were due back on {{ due_date | #{DATE} }}. Please return them as soon as you can: other people may have reserved them.
        #{RETURN_ITEMS}

        If you need more time, or something here is wrong, reply to this email. Late returns can limit your future reservations.

        [View your rentals]({{ rental_url }})

        {{ email_signature }}

        #{POOL_FOOTER}
      LIQUID
    },
    'deadline_soon_reminder' => {
      subject: 'Items due back tomorrow',
      body: <<~LIQUID
        # Items due back tomorrow

        Hi {{ user.name }},

        A quick reminder: these items from {{ inventory_pool.name }} are due back on {{ due_date | #{DATE} }}.
        #{RETURN_ITEMS}

        Someone may be waiting for them, so try to return them on time. If you need more time, reply to this email.

        [View your rentals]({{ rental_url }})

        {{ email_signature }}

        #{POOL_FOOTER}
      LIQUID
    }
  }.freeze

  LOCALES = %w[en-GB en-US].freeze

  def up
    add_column :emails, :format, :text, null: false, default: 'text'
    execute <<~SQL
      ALTER TABLE emails ADD CONSTRAINT emails_format_check
        CHECK (format IN ('text', 'markdown'));
    SQL

    execute <<~SQL
      CREATE TABLE mail_templates_pre_087 AS
        SELECT id, format, subject, body FROM mail_templates WHERE FALSE;
    SQL

    TEMPLATES.each do |name, t|
      LOCALES.each do |locale|
        # pool templates still equal to the template they were copied from
        pool_rows = <<~SQL
          FROM mail_templates AS template
          WHERE template.is_template_template = TRUE
            AND pool_template.is_template_template = FALSE
            AND template.name = #{quote(name)}
            AND template.language_locale = #{quote(locale)}
            AND template.format = 'text'
            AND pool_template.name = template.name
            AND pool_template.language_locale = template.language_locale
            AND pool_template.format = 'text'
            AND pool_template.body = template.body
        SQL

        execute <<~SQL
          INSERT INTO mail_templates_pre_087 (id, format, subject, body)
          SELECT pool_template.id, pool_template.format,
                 pool_template.subject, pool_template.body
          FROM mail_templates AS pool_template, #{pool_rows.sub(/\AFROM /, '')}
        SQL

        execute <<~SQL
          UPDATE mail_templates AS pool_template
          SET format = 'markdown',
              body = #{quote(t[:body])},
              subject = CASE WHEN pool_template.subject IS NOT DISTINCT FROM template.subject
                             THEN #{quote(t[:subject])}
                             ELSE pool_template.subject END,
              updated_at = now()
          #{pool_rows}
        SQL

        execute <<~SQL
          INSERT INTO mail_templates_pre_087 (id, format, subject, body)
          SELECT id, format, subject, body FROM mail_templates
          WHERE is_template_template = TRUE
            AND name = #{quote(name)}
            AND language_locale = #{quote(locale)}
            AND format = 'text';
        SQL

        execute <<~SQL
          UPDATE mail_templates
          SET format = 'markdown',
              body = #{quote(t[:body])},
              subject = #{quote(t[:subject])},
              updated_at = now()
          WHERE is_template_template = TRUE
            AND name = #{quote(name)}
            AND language_locale = #{quote(locale)}
            AND format = 'text';
        SQL
      end
    end
  end

  def down
    execute <<~SQL
      UPDATE mail_templates
      SET format = old.format, subject = old.subject, body = old.body,
          updated_at = now()
      FROM mail_templates_pre_087 AS old
      WHERE mail_templates.id = old.id;
    SQL
    execute 'DROP TABLE mail_templates_pre_087;'
    remove_column :emails, :format
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
