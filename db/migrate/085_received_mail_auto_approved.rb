class ReceivedMailAutoApproved < ActiveRecord::Migration[7.2]
  # The "received order" mail to the pool says the order is pending. Orders
  # approved on submission (inventory_pools.auto_approve_same_day) get the
  # variable approved = true, and the received templates say so instead.
  # Only templates that still hold the original text change.

  TEXTS = [
    [<<~PENDING.chomp, <<~APPROVED.chomp],
      This order is still pending. Please log in to your leihs system and either approve or reject it.

      The user who placed this order has received a similar e-mail message informing them that the order first needs to be approved before it is valid.
    PENDING
      This order was approved automatically (a reservation by the hour within the same day). There is nothing to approve; please have the items ready for pick up.

      The user who placed this order has received an e-mail message confirming the approval.
    APPROVED
    [<<~PENDING.chomp, <<~APPROVED.chomp],
      Este pedido todavía está pendiente. Inicia sesión en leihs para aprobarlo o rechazarlo.

      La persona que hizo el pedido ha recibido un mensaje parecido que le informa de que el pedido debe aprobarse antes de ser válido.
    PENDING
      Este pedido se aprobó automáticamente (reserva por horas dentro del mismo día). No hace falta aprobarlo; prepara el material para la recogida.

      La persona que hizo el pedido ha recibido un mensaje que le confirma la aprobación.
    APPROVED
    [<<~PENDING.chomp, <<~APPROVED.chomp]
      Aquesta comanda encara està pendent. Inicia la sessió a leihs per aprovar-la o rebutjar-la.

      La persona que ha fet la comanda ha rebut un missatge semblant que l'informa que la comanda s'ha d'aprovar abans de ser vàlida.
    PENDING
      Aquesta comanda s'ha aprovat automàticament (reserva per hores dins del mateix dia). No cal aprovar-la; prepara el material per a la recollida.

      La persona que ha fet la comanda ha rebut un missatge que li confirma l'aprovació.
    APPROVED
  ]

  def up
    TEXTS.each do |pending, approved|
      execute <<~SQL
        UPDATE mail_templates
        SET body = replace(body, #{quote(pending)},
                           #{quote("{% if approved %}#{approved}{% else %}#{pending}{% endif %}")})
        WHERE name = 'received'
          AND strpos(body, #{quote(pending)}) > 0
          AND strpos(body, '{% if approved %}') = 0;
      SQL
    end
  end

  def down
    TEXTS.each do |pending, approved|
      execute <<~SQL
        UPDATE mail_templates
        SET body = replace(body,
                           #{quote("{% if approved %}#{approved}{% else %}#{pending}{% endif %}")},
                           #{quote(pending)})
        WHERE name = 'received';
      SQL
    end
  end

  private

  def quote(text)
    connection.quote(text)
  end
end
