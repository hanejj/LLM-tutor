class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.string :name
      t.string :features
      t.datetime :expires_at

      t.timestamps
    end
  end
end
