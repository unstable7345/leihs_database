class NotificationEmail < ActiveRecord::Migration[7.2]
  # Address that receives the "received order" notifications of a pool,
  # apart from inventory_pools.email, which is also the sender of every mail
  # of the pool and with Microsoft 365 must be an authorized mailbox. Empty:
  # the notifications go to inventory_pools.email, as before.

  def up
    execute <<~SQL
      ALTER TABLE inventory_pools ADD COLUMN notification_email text;

      ALTER TABLE inventory_pools ADD CONSTRAINT inventory_pools_notification_email_valid
        CHECK (notification_email IS NULL OR
               notification_email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$');
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE inventory_pools DROP CONSTRAINT inventory_pools_notification_email_valid;
      ALTER TABLE inventory_pools DROP COLUMN notification_email;
    SQL
  end
end
