class Membership < ApplicationRecord
    has_many :users

    validates :name, presence: true
    validates :features, presence: true
    validates :expires_at, presence: true
    validates :coupon_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
    
    # 만료일이 과거가 아닌지 검증 (생성 시에만)
    validate :expires_at_cannot_be_in_the_past, on: :create
    
    # 멤버십이 현재 유효한지 확인
    def active?
      expires_at >= Time.current
    end
    
    # 특정 기능을 포함하는지 확인
    def has_feature?(feature_name)
      features_array.include?(feature_name)
    end
    
    # features를 배열로 반환
    def features_array
      features.to_s.split(',').map(&:strip)
    end
    
    private
    
    def expires_at_cannot_be_in_the_past
      if expires_at.present? && expires_at < Time.current
        errors.add(:expires_at, "는 과거 날짜일 수 없습니다")
      end
    end
end
