class OutlookCalendarEventsCalendar < ActiveRecord::Migration[7.2]
  # The calendar of the mailbox that holds each event, so the calendar-sync
  # service knows when an event has to go to another calendar (one calendar
  # per space). Empty for the events created before: they are in the
  # calendar the service was configured with then.

  def up
    execute <<~SQL
      ALTER TABLE outlook_calendar_events ADD COLUMN calendar text;
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE outlook_calendar_events DROP COLUMN calendar;
    SQL
  end
end
