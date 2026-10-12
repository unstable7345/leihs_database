class DropTimeSlots < ActiveRecord::Migration[7.2]
  def up
    # Replaced by reservations by the hour within the hours of the pool (see
    # 076_add_hourly_reservations), which took over the hours of the slots.
    drop_table :time_slots
  end

  def down
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
  end
end
