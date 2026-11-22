class TranslatedMailTemplates < ActiveRecord::Migration[7.2]
  # The mail templates in the other languages (ca, es, de-CH, fr-CH,
  # gsw-CH) are rewritten in Markdown like the English ones (087, 088, 089,
  # 090): short texts, no signature, no pool footer, a tone marker on top.
  # Until now de-CH, fr-CH and gsw-CH still held the English text of leihs.
  #
  # Dates are numeric: the names of days and months would depend on the
  # language of the server, not on the language of the mail.
  #
  # As in 087, pool templates change only while they still hold the text of
  # the template they were copied from; customized ones stay as they are.
  # The rows this changes are kept in mail_templates_pre_091 for `down`.

  def self.items(date)
    d = ->(v) { "{{ #{v} | date: '#{date}' }}" }
    <<~LIQUID.chomp
      {% for l in reservations %}
      - **{{ l.quantity }} × {{ l.model_name }}** · {% if l.time_slot %}#{d['l.start_date']}, {{ l.time_slot }}{% elsif l.start_date == l.end_date %}#{d['l.start_date']}{% else %}#{d['l.start_date']} – #{d['l.end_date']}{% endif %}{% endfor %}
    LIQUID
  end

  RETURN_ITEMS = <<~LIQUID.chomp
    {% for l in reservations %}
    - **{{ l.quantity }} × {{ l.model_name }}**{% if l.item_inventory_code %} · {{ l.item_inventory_code }}{% endif %}{% if l.time_slot %} · {{ l.time_slot }}{% endif %}{% endfor %}
  LIQUID

  COMMENT = <<~LIQUID.chomp
    {% if comment and comment != "" %}
    > {{ comment }}
    {% endif %}
  LIQUID

  # t: the texts of one language
  def self.templates(t)
    items = items(t[:date])
    due = "{{ due_date | date: '#{t[:date]}' }}"
    footer = "---\n\n#{t[:automatic]}"
    {
      'submitted' => {
        subject: t[:submitted_title],
        body: <<~LIQUID
          <!-- amber -->
          # #{t[:submitted_title]}

          #{t[:hi]}

          #{t[:submitted_text]}
          #{items}

          ### #{t[:purpose]}
          {{ purpose }}

          [#{t[:view_order]}]({{ rental_url }})

          #{footer}
        LIQUID
      },
      'approved' => {
        subject: t[:approved_title],
        body: <<~LIQUID
          <!-- green -->
          # #{t[:approved_title]}

          #{t[:hi]}

          #{t[:approved_text]}
          #{items}

          #{COMMENT}

          [#{t[:view_order]}]({{ rental_url }})

          #{footer}
        LIQUID
      },
      'rejected' => {
        subject: t[:rejected_title],
        body: <<~LIQUID
          <!-- red -->
          # #{t[:rejected_title]}

          #{t[:hi]}

          #{t[:rejected_text]}
          #{items}

          #{COMMENT}

          #{t[:rejected_questions]}

          #{footer}
        LIQUID
      },
      'received' => {
        subject: "[leihs] #{t[:received_subject]}",
        body: <<~LIQUID
          {% if approved %}<!-- green -->{% else %}<!-- amber -->{% endif %}
          # {% if approved %}#{t[:received_title_auto]}{% else %}#{t[:received_title]}{% endif %}

          #{t[:received_text]}
          #{items}

          ### #{t[:purpose]}
          {{ purpose }}

          {% if approved %}#{t[:received_auto]}{% else %}#{t[:received_waiting]}{% endif %}

          [#{t[:open_order]}]({{ order_url }})

          #{footer}
        LIQUID
      },
      'reminder' => {
        subject: t[:reminder_title],
        body: <<~LIQUID
          <!-- red -->
          # #{t[:reminder_title]}

          #{t[:hi]}

          #{format(t[:reminder_text], due: due)}
          #{RETURN_ITEMS}

          #{t[:reminder_more_time]}

          [#{t[:view_rentals]}]({{ rental_url }})

          #{footer}
        LIQUID
      },
      'deadline_soon_reminder' => {
        subject: t[:deadline_title],
        body: <<~LIQUID
          <!-- amber -->
          # #{t[:deadline_title]}

          #{t[:hi]}

          #{format(t[:deadline_text], due: due)}
          #{RETURN_ITEMS}

          #{t[:deadline_more_time]}

          [#{t[:view_rentals]}]({{ rental_url }})

          #{footer}
        LIQUID
      }
    }
  end

  TEXTS = {
    'es' => {
      date: '%d/%m/%Y',
      hi: 'Hola, {{ user.name }}:',
      purpose: 'Finalidad',
      view_order: 'Ver el pedido',
      open_order: 'Abrir el pedido',
      view_rentals: 'Ver los préstamos',
      automatic: 'Este es un mensaje automático de leihs.',
      submitted_title: 'Recibimos tu pedido',
      submitted_text: 'Tu pedido en {{ inventory_pool.name }} está pendiente de aprobación. ' \
                      'Llegará otro correo en cuanto el equipo lo revise.',
      approved_title: 'Tu pedido está confirmado',
      approved_text: '{{ inventory_pool.name }} aprobó tu pedido. ' \
                     'Los artículos se recogen al comienzo de la reserva.',
      rejected_title: 'No se pudo aprobar tu pedido',
      rejected_text: '{{ inventory_pool.name }} no pudo aprobar tu pedido de estos artículos:',
      rejected_questions: 'Para cualquier duda, basta con responder a este correo.',
      received_subject: 'Pedido nuevo',
      received_title: 'Pedido nuevo para revisar',
      received_title_auto: 'Pedido nuevo, aprobado automáticamente',
      received_text: '{{ user.name }} hizo un pedido en {{ inventory_pool.name }}.',
      received_auto: 'Se aprobó automáticamente, por ser una reserva por horas dentro del mismo día. ' \
                     'No hay nada que aprobar: solo hace falta tener los artículos listos para la recogida.',
      received_waiting: 'Está pendiente de aprobación. Quien lo hizo sabe que no es válido hasta que se apruebe.',
      reminder_title: 'Hay artículos atrasados',
      reminder_text: 'El plazo para devolver estos artículos de {{ inventory_pool.name }} venció el %<due>s. ' \
                     'Es importante devolverlos cuanto antes: otras personas pueden tenerlos reservados.',
      reminder_more_time: 'Para pedir más tiempo, o si algo de esto no es correcto, basta con responder ' \
                          'a este correo. Las devoluciones con retraso pueden limitar las próximas reservas.',
      deadline_title: 'Artículos para devolver mañana',
      deadline_text: 'Un recordatorio: estos artículos de {{ inventory_pool.name }} se devuelven el %<due>s.',
      deadline_more_time: 'Puede que alguien los esté esperando, así que conviene devolverlos a tiempo. ' \
                          'Para pedir más tiempo, basta con responder a este correo.'
    },
    'ca' => {
      date: '%d/%m/%Y',
      hi: 'Hola, {{ user.name }}:',
      purpose: 'Finalitat',
      view_order: 'Veure la comanda',
      open_order: 'Obrir la comanda',
      view_rentals: 'Veure els préstecs',
      automatic: 'Aquest és un missatge automàtic de leihs.',
      submitted_title: 'Hem rebut la teva comanda',
      submitted_text: 'La teva comanda a {{ inventory_pool.name }} està pendent d’aprovació. ' \
                      'Rebràs un altre correu quan l’equip l’hagi revisat.',
      approved_title: 'La teva comanda està confirmada',
      approved_text: '{{ inventory_pool.name }} ha aprovat la teva comanda. ' \
                     'Recull els articles a l’inici de la reserva.',
      rejected_title: 'No s’ha pogut aprovar la teva comanda',
      rejected_text: '{{ inventory_pool.name }} no ha pogut aprovar la teva comanda d’aquests articles:',
      rejected_questions: 'Si tens cap dubte, respon aquest correu.',
      received_subject: 'Comanda nova',
      received_title: 'Comanda nova per revisar',
      received_title_auto: 'Comanda nova, aprovada automàticament',
      received_text: '{{ user.name }} ha fet una comanda a {{ inventory_pool.name }}.',
      received_auto: 'S’ha aprovat automàticament, perquè és una reserva per hores dins del mateix dia. ' \
                     'No cal aprovar res: només cal tenir els articles a punt per recollir.',
      received_waiting: 'Està pendent d’aprovació. Qui l’ha fet sap que no és vàlida fins que s’aprovi.',
      reminder_title: 'Hi ha articles endarrerits',
      reminder_text: 'El termini per retornar aquests articles de {{ inventory_pool.name }} va vèncer el %<due>s. ' \
                     'Retorna’ls tan aviat com puguis: altres persones poden tenir-los reservats.',
      reminder_more_time: 'Si necessites més temps, o hi ha alguna cosa que no és correcta, respon aquest ' \
                          'correu. Els retorns amb retard poden limitar les teves properes reserves.',
      deadline_title: 'Articles per retornar demà',
      deadline_text: 'Un recordatori: aquests articles de {{ inventory_pool.name }} s’han de retornar el %<due>s.',
      deadline_more_time: 'Potser algú els està esperant, així que intenta retornar-los a temps. ' \
                          'Si necessites més temps, respon aquest correu.'
    },
    'de-CH' => {
      date: '%d.%m.%Y',
      hi: 'Hallo {{ user.name }}',
      purpose: 'Zweck',
      view_order: 'Bestellung ansehen',
      open_order: 'Bestellung öffnen',
      view_rentals: 'Ausleihen ansehen',
      automatic: 'Dies ist eine automatische Nachricht von leihs.',
      submitted_title: 'Wir haben Ihre Bestellung erhalten',
      submitted_text: 'Ihre Bestellung bei {{ inventory_pool.name }} wartet auf Genehmigung. ' \
                      'Sie erhalten eine weitere E-Mail, sobald das Team sie geprüft hat.',
      approved_title: 'Ihre Bestellung ist bestätigt',
      approved_text: '{{ inventory_pool.name }} hat Ihre Bestellung genehmigt. ' \
                     'Holen Sie die Gegenstände zu Beginn Ihrer Reservation ab.',
      rejected_title: 'Ihre Bestellung wurde nicht genehmigt',
      rejected_text: '{{ inventory_pool.name }} konnte Ihre Bestellung für diese Gegenstände nicht genehmigen:',
      rejected_questions: 'Bei Fragen antworten Sie einfach auf diese E-Mail.',
      received_subject: 'Neue Bestellung',
      received_title: 'Neue Bestellung zu prüfen',
      received_title_auto: 'Neue Bestellung, automatisch genehmigt',
      received_text: '{{ user.name }} hat bei {{ inventory_pool.name }} eine Bestellung aufgegeben.',
      received_auto: 'Sie wurde automatisch genehmigt, da es eine stundenweise Reservation am selben Tag ist. ' \
                     'Es gibt nichts zu genehmigen: Halten Sie die Gegenstände zur Abholung bereit.',
      received_waiting: 'Sie wartet auf Ihre Genehmigung. Die Person, die sie aufgegeben hat, weiss, ' \
                        'dass sie erst nach der Genehmigung gilt.',
      reminder_title: 'Einige Gegenstände sind überfällig',
      reminder_text: 'Diese Gegenstände von {{ inventory_pool.name }} hätten am %<due>s zurückgegeben werden sollen. ' \
                     'Bitte bringen Sie sie so bald wie möglich zurück: Andere Personen haben sie vielleicht reserviert.',
      reminder_more_time: 'Wenn Sie mehr Zeit brauchen oder hier etwas nicht stimmt, antworten Sie auf diese ' \
                          'E-Mail. Verspätete Rückgaben können Ihre künftigen Reservationen einschränken.',
      deadline_title: 'Rückgabe morgen',
      deadline_text: 'Eine kurze Erinnerung: Diese Gegenstände von {{ inventory_pool.name }} ' \
                     'müssen am %<due>s zurückgegeben werden.',
      deadline_more_time: 'Vielleicht wartet schon jemand darauf, bringen Sie sie also bitte rechtzeitig zurück. ' \
                          'Wenn Sie mehr Zeit brauchen, antworten Sie auf diese E-Mail.'
    },
    'fr-CH' => {
      date: '%d.%m.%Y',
      hi: 'Bonjour {{ user.name }},',
      purpose: 'Motif',
      view_order: 'Voir la commande',
      open_order: 'Ouvrir la commande',
      view_rentals: 'Voir vos emprunts',
      automatic: 'Ceci est un message automatique de leihs.',
      submitted_title: 'Nous avons bien reçu votre commande',
      submitted_text: 'Votre commande auprès de {{ inventory_pool.name }} attend d’être approuvée. ' \
                      'Vous recevrez un autre e-mail dès que l’équipe l’aura examinée.',
      approved_title: 'Votre commande est confirmée',
      approved_text: '{{ inventory_pool.name }} a approuvé votre commande. ' \
                     'Venez chercher les objets au début de votre réservation.',
      rejected_title: 'Votre commande n’a pas été approuvée',
      rejected_text: '{{ inventory_pool.name }} n’a pas pu approuver votre commande pour ces objets :',
      rejected_questions: 'Pour toute question, répondez simplement à cet e-mail.',
      received_subject: 'Nouvelle commande',
      received_title: 'Nouvelle commande à examiner',
      received_title_auto: 'Nouvelle commande, approuvée automatiquement',
      received_text: '{{ user.name }} a passé une commande auprès de {{ inventory_pool.name }}.',
      received_auto: 'Elle a été approuvée automatiquement, car c’est une réservation à l’heure dans la même ' \
                     'journée. Il n’y a rien à approuver : préparez simplement les objets pour le retrait.',
      received_waiting: 'Elle attend votre approbation. La personne qui l’a passée sait qu’elle n’est valable ' \
                        'qu’une fois approuvée.',
      reminder_title: 'Des objets sont en retard',
      reminder_text: 'Ces objets de {{ inventory_pool.name }} devaient être rendus le %<due>s. ' \
                     'Merci de les rapporter dès que possible : d’autres personnes les ont peut-être réservés.',
      reminder_more_time: 'Si vous avez besoin de plus de temps, ou si quelque chose est incorrect, répondez à ' \
                          'cet e-mail. Les retours en retard peuvent limiter vos prochaines réservations.',
      deadline_title: 'Objets à rendre demain',
      deadline_text: 'Petit rappel : ces objets de {{ inventory_pool.name }} doivent être rendus le %<due>s.',
      deadline_more_time: 'Quelqu’un les attend peut-être, alors essayez de les rendre à temps. ' \
                          'Si vous avez besoin de plus de temps, répondez à cet e-mail.'
    },
    'gsw-CH' => {
      date: '%d.%m.%Y',
      hi: 'Hoi {{ user.name }}',
      purpose: 'Zwäck',
      view_order: 'Bstellig aaluege',
      open_order: 'Bstellig uftue',
      view_rentals: 'Uusleihe aaluege',
      automatic: 'Das isch e automatischi Nachricht vo leihs.',
      submitted_title: 'Mir händ Ihri Bstellig übercho',
      submitted_text: 'Ihri Bstellig bi {{ inventory_pool.name }} wartet uf d Gnehmigung. ' \
                      'Sie überchömed e wiiteri E-Mail, sobald s Team sie aagluegt hät.',
      approved_title: 'Ihri Bstellig isch bschtätigt',
      approved_text: '{{ inventory_pool.name }} hät Ihri Bstellig gnehmigt. ' \
                     'Holed Sie d Sache am Aafang vo Ihrer Reservation ab.',
      rejected_title: 'Ihri Bstellig isch nöd gnehmigt worde',
      rejected_text: '{{ inventory_pool.name }} hät Ihri Bstellig für die Sache nöd chöne gnehmige:',
      rejected_questions: 'Wänn Sie Frage händ, antworted Sie eifach uf die E-Mail.',
      received_subject: 'Neui Bstellig',
      received_title: 'Neui Bstellig zum Prüefe',
      received_title_auto: 'Neui Bstellig, automatisch gnehmigt',
      received_text: '{{ user.name }} hät bi {{ inventory_pool.name }} e Bstellig gmacht.',
      received_auto: 'Sie isch automatisch gnehmigt worde, will s e Reservation nach Stunde am gliiche Tag isch. ' \
                     'Es git nüt z gnehmige: Mached Sie d Sache für d Abholig parat.',
      received_waiting: 'Sie wartet uf Ihri Gnehmigung. D Person, wo sie gmacht hät, weiss, ' \
                        'dass sie erscht nach de Gnehmigung gilt.',
      reminder_title: 'Es paar Sache sind überfällig',
      reminder_text: 'Die Sache vo {{ inventory_pool.name }} hetted am %<due>s sölle zruggbracht werde. ' \
                     'Bitte bringed Sie sie so schnäll wie möglich zrugg: Anderi händ sie vilicht reserviert.',
      reminder_more_time: 'Wänn Sie meh Ziit bruuched oder öppis da nöd stimmt, antworted Sie uf die E-Mail. ' \
                          'Wer z spaat zruggbringt, cha spöter weniger reserviere.',
      deadline_title: 'Morn zruggbringe',
      deadline_text: 'E churzi Erinnerig: Die Sache vo {{ inventory_pool.name }} münd am %<due>s ' \
                     'zruggbracht werde.',
      deadline_more_time: 'Vilicht wartet scho öpper druf, bringed Sie sie also bitte rächtziitig zrugg. ' \
                          'Wänn Sie meh Ziit bruuched, antworted Sie uf die E-Mail.'
    }
  }.freeze

  def up
    execute <<~SQL
      CREATE TABLE mail_templates_pre_091 AS
        SELECT id, format, subject, body FROM mail_templates WHERE FALSE;
    SQL

    TEXTS.each do |locale, texts|
      self.class.templates(texts).each do |name, t|
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
          INSERT INTO mail_templates_pre_091 (id, format, subject, body)
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
          INSERT INTO mail_templates_pre_091 (id, format, subject, body)
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
      FROM mail_templates_pre_091 AS old
      WHERE mail_templates.id = old.id;
    SQL
    execute 'DROP TABLE mail_templates_pre_091;'
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
