class AddChatPointsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :chat_coupons, :integer
  end
end
