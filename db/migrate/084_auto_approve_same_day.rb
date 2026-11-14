class AutoApproveSameDay < ActiveRecord::Migration[7.2]
  # Orders whose reservations are all by the hour and start and end on the
  # same day (the material does not leave the premises overnight) are
  # approved automatically when they are submitted, if the pool wants it.
  # Whole days, or by the hour across several days, still need approval.

  def up
    add_column :inventory_pools, :auto_approve_same_day, :boolean,
               null: false, default: false
  end

  def down
    remove_column :inventory_pools, :auto_approve_same_day
  end
end
