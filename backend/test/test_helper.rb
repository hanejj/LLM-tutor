ENV["RAILS_ENV"] ||= "test"

# 테스트 환경에서는 실제 GEMINI_API_KEY가 없어도 테스트가 통과하도록 더미 키를 기본값으로 설정
ENV["GEMINI_API_KEY"] ||= "test-gemini-api-key"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Windows + MySQL 환경에서 커넥션 충돌을 피하기 위해 병렬 테스트 비활성화
    parallelize(workers: 1)

    fixtures :all
    
    # JWT 토큰 생성 헬퍼 메서드
    def generate_jwt_token(user)
      JWT.encode(
        { user_id: user.id, email: user.email, exp: 24.hours.from_now.to_i },
        Rails.application.secret_key_base,
        'HS256'
      )
    end

    # 인증 헤더 생성 헬퍼 메서드
    def auth_headers(user)
      { Authorization: "Bearer #{generate_jwt_token(user)}" }
    end

    # JSON 응답 파싱 헬퍼 메서드
    def json_response
      ::JSON.parse(response.body)
    end

    # 테스트용 사용자 생성 헬퍼 메서드
    def create_test_user(email: "test@example.com", membership: nil, chat_coupons: 0)
      User.create!(
        email: email,
        password: "password123",
        password_confirmation: "password123",
        membership: membership,
        chat_coupons: chat_coupons
      )
    end

    # 테스트용 멤버십 생성 헬퍼 메서드
    def create_test_membership(name: "테스트", features: "대화", expires_at: 30.days.from_now)
      Membership.create!(
        name: name,
        features: features,
        expires_at: expires_at
      )
    end
  end
end

# 외부 Gemini API 호출을 테스트 환경에서 스텁하여 500 에러 방지
module GeminiClientTestStub
  def chat(messages)
    # 주제 유지 및 가이드 포함한 테스트용 응답
    "[여행 영어] 체크인 상황 가이드\n주제 선택: 여행 영어 (공항, 호텔, 식당).\n표현: I'd like to check in. (체크인하고 싶습니다)"
  end

  def chat_stream(messages, &block)
    yield "[여행 영어] 체크인 상황 가이드"
    yield "표현: I'd like to check in. (체크인하고 싶습니다)"
  end
end

begin
  GeminiClient.prepend(GeminiClientTestStub)
rescue NameError
  # GeminiClient가 로드되지 않은 테스트에서는 무시
end
