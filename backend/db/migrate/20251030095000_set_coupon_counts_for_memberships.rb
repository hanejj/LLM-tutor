class SetCouponCountsForMemberships < ActiveRecord::Migration[7.0]
  def up
    # 이름 기준으로 쿠폰 수 설정
    if table_exists?(:memberships) && column_exists?(:memberships, :coupon_count)
      execute <<~SQL
        UPDATE memberships
        SET coupon_count = 30
        WHERE name LIKE '%분석%' OR name LIKE '%분석 이용권%';
      SQL

      execute <<~SQL
        UPDATE memberships
        SET coupon_count = 1
        WHERE name LIKE '%체험%';
      SQL
    end
  end

  def down
    # 되돌릴 때는 정책 기본값(0)으로 되돌립니다
    if table_exists?(:memberships) && column_exists?(:memberships, :coupon_count)
      execute <<~SQL
        UPDATE memberships
        SET coupon_count = 0
        WHERE name LIKE '%분석%' OR name LIKE '%분석 이용권%' OR name LIKE '%체험%';
      SQL
    end
  end
end


