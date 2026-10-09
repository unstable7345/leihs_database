class AddReturnedAtToReservations < ActiveRecord::Migration[7.2]
  def up
    # The moment an item was taken back (returned_date only has the day). With
    # the time of the hand over (contracts.created_at) it tells who had an
    # item at which time. Unknown (NULL) for reservations returned before.
    add_column :reservations, :returned_at, :timestamp
  end

  def down
    remove_column :reservations, :returned_at
  end
end
