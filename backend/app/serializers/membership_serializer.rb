# frozen_string_literal: true

class MembershipSerializer
  def self.as_json(membership)
    return nil unless membership

    {
      id: membership.id,
      name: membership.name,
      features: membership.features_array,
      expires_at: membership.expires_at,
      coupon_count: membership.coupon_count || 0
    }
  end
end


