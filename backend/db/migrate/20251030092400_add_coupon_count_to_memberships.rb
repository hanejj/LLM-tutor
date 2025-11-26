class AddCouponCountToMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :memberships, :coupon_count, :integer, default: 0, null: false
  end
end
