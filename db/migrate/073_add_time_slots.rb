class AddTimeSlots < ActiveRecord::Migration[7.2]
  def up
    # Time slots offered by an inventory pool for same-day reservations
    # (e.g. "Morning" 08:00-13:00, "Afternoon" 13:00-18:00). A pool without
    # time slots only offers whole-day reservations, as before.
    create_table :time_slots, id: :uuid do |t|
      t.uuid :inventory_pool_id, null: false
      t.text :name, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :position, null: false, default: 0
      t.timestamps null: false, default: -> { "now()" }
    end

    add_foreign_key :time_slots, :inventory_pools, on_delete: :cascade
    add_index :time_slots, [:inventory_pool_id, :name], unique: true

    execute <<~SQL
      ALTER TABLE time_slots
        ADD CONSTRAINT time_slots_name_not_blank CHECK (name !~ '^\\s*$'),
        ADD CONSTRAINT time_slots_start_time_before_end_time CHECK (start_time < end_time);
    SQL

    # A reservation with start_time/end_time only occupies that window of its
    # (single) day. Without them it occupies the whole days, as before.
    add_column :reservations, :start_time, :time
    add_column :reservations, :end_time, :time

    execute <<~SQL
      ALTER TABLE reservations
        ADD CONSTRAINT check_time_window_complete
          CHECK ((start_time IS NULL) = (end_time IS NULL)),
        ADD CONSTRAINT check_time_window_start_before_end
          CHECK (start_time IS NULL OR start_time < end_time),
        ADD CONSTRAINT check_time_window_single_day
          CHECK (start_time IS NULL OR start_date = end_date);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE reservations
        DROP CONSTRAINT check_time_window_complete,
        DROP CONSTRAINT check_time_window_start_before_end,
        DROP CONSTRAINT check_time_window_single_day;
    SQL
    remove_column :reservations, :end_time
    remove_column :reservations, :start_time
    drop_table :time_slots
  end
end
