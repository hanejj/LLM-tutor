# frozen_string_literal: true

module MembershipPolicy
  module_function

  def coupon_count_for(membership_name)
    name = membership_name.to_s
    if name.match?(/베이직/i)
      env_int(ENV.fetch('COUPON_BASIC', '0'))
    elsif name.match?(/프리미엄/i)
      env_int(ENV.fetch('COUPON_PREMIUM', '30'))
    else
      env_int(ENV.fetch('COUPON_DEFAULT', '0'))
    end
  end

  def env_int(value)
    Integer(value.to_s, 10)
  rescue ArgumentError
    0
  end
end


