# frozen_string_literal: true

class UserSerializer
  def self.as_json(user)
    return nil unless user

    {
      id: user.id,
      email: user.email,
      chat_coupons: user.chat_coupons,
      membership: MembershipSerializer.as_json(user.membership)
    }
  end
end


