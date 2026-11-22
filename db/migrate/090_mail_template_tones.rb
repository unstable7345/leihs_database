class MailTemplateTones < ActiveRecord::Migration[7.2]
  # The Markdown mail templates start with a tone marker, which the mail
  # service shows as a colored stripe and an icon next to the title:
  # green when an order is approved, red when it is rejected or items are
  # overdue, amber while an order waits for approval or items are due soon.

  TONES = {
    'approved' => '<!-- green -->',
    'rejected' => '<!-- red -->',
    'reminder' => '<!-- red -->',
    'submitted' => '<!-- amber -->',
    'deadline_soon_reminder' => '<!-- amber -->',
    'received' => '{% if approved %}<!-- green -->{% else %}<!-- amber -->{% endif %}'
  }.freeze

  def up
    TONES.each do |name, marker|
      execute <<~SQL
        UPDATE mail_templates
        SET body = #{quote("#{marker}\n")} || body, updated_at = now()
        WHERE format = 'markdown'
          AND name = #{quote(name)}
          AND body NOT LIKE '%<!--%';
      SQL
    end
  end

  def down
    TONES.each do |name, marker|
      line = "#{marker}\n"
      execute <<~SQL
        UPDATE mail_templates
        SET body = substr(body, #{line.length + 1}), updated_at = now()
        WHERE format = 'markdown'
          AND name = #{quote(name)}
          AND left(body, #{line.length}) = #{quote(line)};
      SQL
    end
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
