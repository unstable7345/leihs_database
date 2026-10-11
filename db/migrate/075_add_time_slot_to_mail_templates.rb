class AddTimeSlotToMailTemplates < ActiveRecord::Migration[7.2]
  # The time slot of a reservation (l.time_slot, e.g. "10:00–12:00", empty for
  # whole days) follows the end date of each reservation line.
  END_DATE = "{{ l.end_date | date: '%d/%m/%Y' }}"
  TIME_SLOT = "{% if l.time_slot %}, {{ l.time_slot }}{% endif %}"

  def up
    # templates of the inventory pools, unless customized (differing from the
    # template they were copied from)
    execute <<~SQL
      UPDATE mail_templates AS pool_template
      SET body = replace(pool_template.body, #{quote(END_DATE)}, #{quote(END_DATE + TIME_SLOT)})
      FROM mail_templates AS template
      WHERE template.is_template_template = TRUE
        AND pool_template.is_template_template = FALSE
        AND pool_template.name = template.name
        AND pool_template.type = template.type
        AND pool_template.language_locale = template.language_locale
        AND pool_template.format = template.format
        AND pool_template.body = template.body
        AND strpos(pool_template.body, 'l.time_slot') = 0;
    SQL

    # the templates new inventory pools get
    execute <<~SQL
      UPDATE mail_templates
      SET body = replace(body, #{quote(END_DATE)}, #{quote(END_DATE + TIME_SLOT)})
      WHERE is_template_template = TRUE
        AND strpos(body, 'l.time_slot') = 0;
    SQL
  end

  def down
    execute <<~SQL
      UPDATE mail_templates
      SET body = replace(body, #{quote(TIME_SLOT)}, '');
    SQL
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
