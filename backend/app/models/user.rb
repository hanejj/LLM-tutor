class User < ApplicationRecord
  has_secure_password
  
  belongs_to :membership, optional: true  # 아직 없을 수도 있으니까 optional
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create

  # 멤버십 기능 확인
  def has_feature?(feature_name)
    return false if membership.nil?
    return false if membership.expires_at < Time.current
    
    features = membership.features.to_s.split(',').map(&:strip)
    features.include?(feature_name)
  end

  # 멤버십이 유효한지 확인
  def membership_valid?
    membership.present? && membership.expires_at >= Time.current
  end
end
