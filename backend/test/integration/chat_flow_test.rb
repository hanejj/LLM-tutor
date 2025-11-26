require "test_helper"

class ChatFlowTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "프리미엄",
      features: "대화",
      expires_at: 30.days.from_now
    )
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: @membership,
      chat_coupons: 5
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "complete chat flow from start to message" do
    # 1. 채팅 세션 시작
    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "채팅 세션이 시작되었습니다.", json_response["message"]
    assert_equal 4, json_response["remaining_chat_coupons"]

    # 2. AI 메시지 전송 (스트리밍)
    post api_v1_chat_message_stream_path,
      params: {
        user_id: @user.id,
        messages: [
          { role: "user", content: "안녕하세요" }
        ]
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    assert_equal 'text/event-stream', @response.media_type
  end

  test "chat flow with insufficient coupons" do
    @user.update!(chat_coupons: 0)

    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /남은 채팅 쿠폰이 없습니다/, json_response["error"]
  end

  test "chat flow with expired membership" do
    @membership.update!(expires_at: 1.day.ago)

    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /대화 기능을 사용할 수 있는 멤버십이 필요합니다/, json_response["error"]
  end

  test "chat flow with membership without chat feature" do
    @membership.update!(features: "학습")

    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /대화 기능을 사용할 수 있는 멤버십이 필요합니다/, json_response["error"]
  end
end
