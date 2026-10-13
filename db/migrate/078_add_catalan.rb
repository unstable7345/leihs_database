class AddCatalan < ActiveRecord::Migration[7.2]
  # One reservation of a mail: dates, and for reservations by the hour the
  # time of pick up on the first and of return on the last day.
  LINE = "{{ l.quantity }} {{ l.model_name }}, " \
         "{{ l.start_date | date: '%d/%m/%Y' }}{% if l.start_time %} {{ l.start_time }}{% endif %} - " \
         "{{ l.end_date | date: '%d/%m/%Y' }}{% if l.end_time %} {{ l.end_time }}{% endif %}"
  ITEM_LINE = "{{ l.quantity }} {{ l.model_name }} ({{ l.item_inventory_code }}), " \
              "{{ l.start_date | date: '%d/%m/%Y' }}{% if l.start_time %} {{ l.start_time }}{% endif %} - " \
              "{{ l.end_date | date: '%d/%m/%Y' }}{% if l.end_time %} {{ l.end_time }}{% endif %}"

  def self.footer(opening_times, holidays)
    <<~TXT.chomp
      --
      {{ inventory_pool.name }}
      {{ inventory_pool.contact }}

      #{opening_times}
      {{ inventory_pool.workdays }}

      #{holidays}
      {{ inventory_pool.holidays }}

      {{ inventory_pool.description }}
    TXT
  end

  CA_FOOTER = footer("El nostre horari d'atenció és el següent:",
                     'Tingues en compte els nostres dies festius previstos:')
  ES_FOOTER = footer('Nuestro horario de atención es el siguiente:',
                     'Ten en cuenta nuestros días festivos previstos:')

  TEMPLATES = {
    'ca' => {
      'received' => ['[leihs] Comanda rebuda', <<~TXT],
        Hola:

        ** Aquest és un missatge generat automàticament **

        S'ha rebut una comanda dels articles següents en un grup d'inventari del qual ets responsable.

        Grup d'inventari: {{ inventory_pool.name }}
        Usuari: {{ user.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        Motiu:
        {{ purpose }}

        Aquesta comanda encara està pendent. Inicia la sessió a leihs per aprovar-la o rebutjar-la.

        La persona que ha fet la comanda ha rebut un missatge semblant que l'informa que la comanda s'ha d'aprovar abans de ser vàlida.

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
      'submitted' => ['[leihs] Comanda enviada', <<~TXT],
        Hola, {{ user.name }}:

        ** Aquest és un missatge generat automàticament **

        La teva comanda dels articles següents s'ha enviat correctament.

        Grup d'inventari: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        Motiu:
        {{ purpose }}

        La teva comanda encara està pendent, però aviat rebràs la confirmació en un altre correu. Pots consultar l'estat de la comanda al teu compte de leihs.

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
      'approved' => ['[leihs] Comanda confirmada', <<~TXT],
        Hola, {{ user.name }}:

        ** Aquest és un missatge generat automàticament **

        El personal del grup d'inventari ha confirmat la teva comanda dels articles següents:

        Grup d'inventari: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        {% if comment %}

        Comentaris del personal del grup d'inventari:

        {{ comment }}

        {% endif %}

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
      'rejected' => ['[leihs] Comanda rebutjada', <<~TXT],
        Hola, {{ user.name }}:

        ** Aquest és un missatge generat automàticament **

        La teva comanda s'ha rebutjat pel motiu següent:

        Grup d'inventari: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        {{ comment }}

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
      'reminder' => ['[leihs] Recordatori', <<~TXT],
        Hola, {{ user.name }}:

        ** Aquest és un missatge generat automàticament **

        Els articles següents s'havien d'haver retornat o s'han de revisar:

        {{ quantity }} article(s) amb retorn el {{ due_date | date: '%d/%m/%Y' }} al grup d'inventari {{ inventory_pool.name }}
        {% for l in reservations %}
        * #{ITEM_LINE}
        {% endfor %}

        == Algun d'aquests articles és el teu ordinador personal?

        Et demanem que et posis en contacte amb nosaltres com més aviat millor. Potser el teu ordinador necessita una actualització.

        == Algun d'aquests articles és un préstec?

        Com que no hem rebut cap sol·licitud de pròrroga, et demanem que els retornis sense més demora.

        Si no els retornes, bloqueges les reserves d'altres persones. Això és molt injust per a la resta d'usuaris i per al personal del grup d'inventari, perquè els causa moltes molèsties.

        Podries rebre una amonestació, haver de pagar recàrrecs per retard i veure limitat el teu dret a demanar préstecs. Si es repeteix, podries quedar exclòs del sistema de reserves fins a 6 mesos.

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
      'deadline_soon_reminder' => ["[leihs] Alguns articles s'han de retornar demà", <<~TXT]
        Hola, {{ user.name }}:

        ** Aquest és un missatge generat automàticament **

        Els articles següents s'han de retornar demà o s'han de revisar:

        {{ quantity }} article(s) amb retorn el {{ due_date | date: '%d/%m/%Y' }} al grup d'inventari {{ inventory_pool.name }}
        {% for l in reservations %}
        * #{ITEM_LINE}
        {% endfor %}

        == Algun d'aquests articles és el teu ordinador personal?

        Et demanem que et posis en contacte amb nosaltres com més aviat millor. Potser el teu ordinador necessita una actualització.

        == Algun d'aquests articles és un préstec?

        T'enviem aquest recordatori perquè una altra persona ja espera algun d'aquests articles.

        Per respecte a la resta d'usuaris, et demanem que compleixis les dates de retorn.

        Salutacions cordials,

        {{ email_signature }}

        #{CA_FOOTER}
      TXT
    },
    'es' => {
      'received' => ['[leihs] Pedido recibido', <<~TXT],
        Hola:

        ** Este es un mensaje generado automáticamente **

        Se ha recibido un pedido de los siguientes artículos en un grupo de inventario del que eres responsable.

        Grupo de inventario: {{ inventory_pool.name }}
        Usuario: {{ user.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        Motivo:
        {{ purpose }}

        Este pedido todavía está pendiente. Inicia sesión en leihs para aprobarlo o rechazarlo.

        La persona que hizo el pedido ha recibido un mensaje parecido que le informa de que el pedido debe aprobarse antes de ser válido.

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
      'submitted' => ['[leihs] Pedido enviado', <<~TXT],
        Hola, {{ user.name }}:

        ** Este es un mensaje generado automáticamente **

        Tu pedido de los siguientes artículos se ha enviado correctamente.

        Grupo de inventario: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        Motivo:
        {{ purpose }}

        Tu pedido todavía está pendiente, pero pronto recibirás la confirmación en otro correo. Puedes consultar el estado del pedido en tu cuenta de leihs.

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
      'approved' => ['[leihs] Pedido confirmado', <<~TXT],
        Hola, {{ user.name }}:

        ** Este es un mensaje generado automáticamente **

        El personal del grupo de inventario ha confirmado tu pedido de los siguientes artículos:

        Grupo de inventario: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        {% if comment %}

        Comentarios del personal del grupo de inventario:

        {{ comment }}

        {% endif %}

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
      'rejected' => ['[leihs] Pedido rechazado', <<~TXT],
        Hola, {{ user.name }}:

        ** Este es un mensaje generado automáticamente **

        Tu pedido se ha rechazado por el siguiente motivo:

        Grupo de inventario: {{ inventory_pool.name }}

        {% for l in reservations %}
        * #{LINE}
        {% endfor %}

        {{ comment }}

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
      'reminder' => ['[leihs] Recordatorio', <<~TXT],
        Hola, {{ user.name }}:

        ** Este es un mensaje generado automáticamente **

        Los siguientes artículos ya tendrían que haberse devuelto o deben revisarse:

        {{ quantity }} artículo(s) con devolución el {{ due_date | date: '%d/%m/%Y' }} en el grupo de inventario {{ inventory_pool.name }}
        {% for l in reservations %}
        * #{ITEM_LINE}
        {% endfor %}

        == ¿Alguno de estos artículos es tu ordenador personal?

        Te pedimos que te pongas en contacto con nosotros lo antes posible. Puede que tu ordenador necesite una actualización.

        == ¿Alguno de estos artículos es un préstamo?

        Como no hemos recibido ninguna solicitud de prórroga, te pedimos que los devuelvas sin más demora.

        Si no los devuelves, bloqueas las reservas de otras personas. Esto es muy injusto para el resto de usuarios y para el personal del grupo de inventario, porque les causa muchas molestias.

        Podrías recibir una amonestación, tener que pagar recargos por retraso y ver limitado tu derecho a pedir préstamos. Si se repite, podrías quedar excluido del sistema de reservas hasta 6 meses.

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
      'deadline_soon_reminder' => ['[leihs] Algunos artículos deben devolverse mañana', <<~TXT]
        Hola, {{ user.name }}:

        ** Este es un mensaje generado automáticamente **

        Los siguientes artículos deben devolverse mañana o deben revisarse:

        {{ quantity }} artículo(s) con devolución el {{ due_date | date: '%d/%m/%Y' }} en el grupo de inventario {{ inventory_pool.name }}
        {% for l in reservations %}
        * #{ITEM_LINE}
        {% endfor %}

        == ¿Alguno de estos artículos es tu ordenador personal?

        Te pedimos que te pongas en contacto con nosotros lo antes posible. Puede que tu ordenador necesite una actualización.

        == ¿Alguno de estos artículos es un préstamo?

        Te enviamos este recordatorio porque otra persona ya está esperando alguno de estos artículos.

        Por respeto al resto de usuarios, te pedimos que cumplas las fechas de devolución.

        Saludos cordiales,

        {{ email_signature }}

        #{ES_FOOTER}
      TXT
    }
  }.freeze

  def up
    # Català, to be activated in admin (Settings, Languages)
    execute <<~SQL
      INSERT INTO languages (name, locale, "default", active)
        VALUES ('Català', 'ca', FALSE, FALSE)
        ON CONFLICT DO NOTHING;
    SQL

    TEMPLATES['ca'].each do |name, (subject, body)|
      type = template_type(name)
      # the template of the templates (copied by new pools) ...
      execute <<~SQL
        INSERT INTO mail_templates (inventory_pool_id, name, format, subject, body,
                                    is_template_template, type, language_locale)
          VALUES (NULL, #{quote(name)}, 'text', #{quote(subject)}, #{quote(body)},
                  TRUE, #{quote(type)}, 'ca');
      SQL
      # ... and the one of each existing pool
      execute <<~SQL
        INSERT INTO mail_templates (inventory_pool_id, name, format, subject, body,
                                    is_template_template, type, language_locale)
          SELECT id, #{quote(name)}, 'text', #{quote(subject)}, #{quote(body)},
                 FALSE, #{quote(type)}, 'ca'
            FROM inventory_pools;
      SQL
    end

    # The Spanish templates of leihs only had a Spanish subject, the text was
    # English. Translated in the templates of the templates and in the ones
    # of the pools still equal to them (not changed by the pool).
    TEMPLATES['es'].each do |name, (subject, body)|
      execute <<~SQL
        UPDATE mail_templates AS pool_template
          SET subject = #{quote(subject)}, body = #{quote(body)}
          FROM mail_templates AS template_template
          WHERE template_template.is_template_template
            AND template_template.name = #{quote(name)}
            AND template_template.language_locale = 'es'
            AND template_template.format = 'text'
            AND NOT pool_template.is_template_template
            AND pool_template.name = template_template.name
            AND pool_template.language_locale = 'es'
            AND pool_template.format = 'text'
            AND pool_template.body = template_template.body
            AND pool_template.subject IS NOT DISTINCT FROM template_template.subject;
      SQL
      execute <<~SQL
        UPDATE mail_templates
          SET subject = #{quote(subject)}, body = #{quote(body)}
          WHERE is_template_template
            AND name = #{quote(name)}
            AND language_locale = 'es'
            AND format = 'text';
      SQL
    end
  end

  def down
    execute "DELETE FROM mail_templates WHERE language_locale = 'ca';"
    execute "DELETE FROM languages WHERE locale = 'ca';"
    # the Spanish texts stay translated
  end

  private

  def template_type(name)
    %w[reminder deadline_soon_reminder].include?(name) ? 'user' : 'order'
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
