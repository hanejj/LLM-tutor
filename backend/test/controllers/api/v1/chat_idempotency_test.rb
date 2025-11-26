require "test_helper"

class Api::V1::ChatIdempotencyTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "프리미엄",
      features: "학습,대화,분석",
      expires_at: 30.days.from_now
    )
    @user = User.create!(
      email: "idem@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: @membership,
      chat_coupons: 2
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "chat start is idempotent with same key" do
    key = "same-key-123"

    # 첫번째 콜
    post api_v1_chat_start_path,
      params: { user_id: @user.id, idempotency_key: key },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    first = JSON.parse(response.body)
    assert_equal '채팅 세션이 시작되었습니다.', first['message']
    assert_equal 1, first['remaining_chat_coupons']

    # 두번째 콜콜
    post api_v1_chat_start_path,
      params: { user_id: @user.id, idempotency_key: key },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    second = JSON.parse(response.body)
    assert_equal '채팅 세션이 시작되었습니다.', second['message']
    assert_equal 0, second['remaining_chat_coupons']
  end
end


