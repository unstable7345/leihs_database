class OutlookCalendar < ActiveRecord::Migration[7.2]
  # Reservations of models in a category can be copied as events to an
  # Outlook calendar: model_groups.outlook_calendar holds the mailbox for a
  # category (empty = no sync), and outlook_calendar_events is where the
  # calendar-sync service remembers which event belongs to which
  # reservation. No foreign key to reservations: when a reservation is
  # deleted, the row must stay until the service has deleted its event.

  def up
    execute <<~SQL
      ALTER TABLE model_groups ADD COLUMN outlook_calendar text;

      ALTER TABLE model_groups ADD CONSTRAINT model_groups_outlook_calendar_valid
        CHECK (outlook_calendar IS NULL OR (
          type = 'Category' AND
          outlook_calendar ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$'));

      CREATE TABLE outlook_calendar_events (
        reservation_id uuid NOT NULL,
        mailbox text NOT NULL,
        event_id text NOT NULL,
        fingerprint text NOT NULL,
        ends_at timestamp without time zone NOT NULL,
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        updated_at timestamp without time zone DEFAULT now() NOT NULL,
        PRIMARY KEY (reservation_id, mailbox)
      );
    SQL
  end

  def down
    execute <<~SQL
      DROP TABLE outlook_calendar_events;
      ALTER TABLE model_groups DROP CONSTRAINT model_groups_outlook_calendar_valid;
      ALTER TABLE model_groups DROP COLUMN outlook_calendar;
    SQL
  end
end
