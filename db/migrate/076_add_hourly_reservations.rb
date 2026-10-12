class AddHourlyReservations < ActiveRecord::Migration[7.2]
  def up
    # Reservations by the hour: instead of fixed time slots, customers choose
    # the time of pick up and of return within the hours of the pool, also
    # over several days. Pools without it only offer whole days, as before.
    add_column :inventory_pools, :hourly_reservations, :boolean, null: false, default: false
    add_column :inventory_pools, :hourly_reservations_start_time, :time
    add_column :inventory_pools, :hourly_reservations_end_time, :time

    execute <<~SQL
      ALTER TABLE inventory_pools
        ADD CONSTRAINT check_hourly_reservations_times
          CHECK (NOT hourly_reservations
                 OR (hourly_reservations_start_time IS NOT NULL
                     AND hourly_reservations_end_time IS NOT NULL
                     AND hourly_reservations_start_time < hourly_reservations_end_time));
    SQL

    # The hours of the pools with time slots: from the start of the first one
    # to the end of the last one.
    execute <<~SQL
      UPDATE inventory_pools
        SET hourly_reservations = TRUE,
            hourly_reservations_start_time = ts.start_time,
            hourly_reservations_end_time = ts.end_time
        FROM (SELECT inventory_pool_id,
                     min(start_time) AS start_time,
                     max(end_time) AS end_time
                FROM time_slots
                GROUP BY inventory_pool_id) ts
        WHERE ts.inventory_pool_id = inventory_pools.id;
    SQL

    # The longest reservation by the hour the members of a group may make
    # (NULL: no limit). Members of several groups have the highest limit.
    add_column :entitlement_groups, :max_reservation_hours, :integer

    execute <<~SQL
      ALTER TABLE entitlement_groups
        ADD CONSTRAINT check_max_reservation_hours_positive
          CHECK (max_reservation_hours IS NULL OR max_reservation_hours > 0);
    SQL

    # A reservation by the hour runs from start_time of start_date to
    # end_time of end_date, so it may span several days.
    execute <<~SQL
      ALTER TABLE reservations
        DROP CONSTRAINT check_time_window_single_day,
        DROP CONSTRAINT check_time_window_start_before_end,
        ADD CONSTRAINT check_time_window_start_before_end
          CHECK (start_time IS NULL OR start_date + start_time < end_date + end_time);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE reservations
        DROP CONSTRAINT check_time_window_start_before_end,
        ADD CONSTRAINT check_time_window_start_before_end
          CHECK (start_time IS NULL OR start_time < end_time),
        ADD CONSTRAINT check_time_window_single_day
          CHECK (start_time IS NULL OR start_date = end_date);
    SQL
    remove_column :entitlement_groups, :max_reservation_hours
    execute "ALTER TABLE inventory_pools DROP CONSTRAINT check_hourly_reservations_times;"
    remove_column :inventory_pools, :hourly_reservations_end_time
    remove_column :inventory_pools, :hourly_reservations_start_time
    remove_column :inventory_pools, :hourly_reservations
  end
end
