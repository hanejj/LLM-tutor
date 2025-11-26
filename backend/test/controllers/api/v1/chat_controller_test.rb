require "test_helper"

class Api::V1::ChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: @membership,
      chat_coupons: 10
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "message should require auth token" do
    post api_v1_chat_message_path,
      params: { user_id: @user.id, messages: [{ role: 'user', content: '안녕' }] },
      as: :json

    assert_response :unauthorized
  end

  test "message should return error when messages empty" do
    post api_v1_chat_message_path,
      params: { user_id: @user.id, messages: [] },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match /메시지가 비어있습니다/, json_response["error"]
  end

  test "message_stream should set sse content type" do
    # 최소한의 유효 요청
    post api_v1_chat_message_stream_path,
      params: { user_id: @user.id, messages: [{ role: 'user', content: '테스트' }] },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    # 스트리밍은 컨텐츠 타입이 text/event-stream 이어야 함
    assert_equal 'text/event-stream', @response.media_type
  end

  test "should start chat session and deduct coupon" do
    initial_coupons = @user.chat_coupons

    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal "채팅 세션이 시작되었습니다.", json_response["message"]
    assert_equal initial_coupons - 1, json_response["remaining_chat_coupons"]
    
    @user.reload
    assert_equal initial_coupons - 1, @user.chat_coupons
  end

  test "should fail when user has no coupons" do
    @user.update(chat_coupons: 0)

    post api_v1_chat_start_path,
      params: { user_id: @user.id },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /남은 채팅 쿠폰이 없습니다/, json_response["error"]
  end

  test "should fail when user has no membership" do
    user_no_membership = User.create!(
      email: "nomembership@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    token = JWT.encode(
      { user_id: user_no_membership.id, email: user_no_membership.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )

    post api_v1_chat_start_path,
      params: { user_id: user_no_membership.id },
      headers: { Authorization: "Bearer #{token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /대화 기능을 사용할 수 있는 멤버십이 필요합니다/, json_response["error"]
  end

  test "should fail when membership does not include chat feature" do
    membership_no_chat = Membership.create!(
      name: "학습 전용",
      features: "학습",
      expires_at: 30.days.from_now
    )
    user_no_chat = User.create!(
      email: "nochat@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: membership_no_chat,
      chat_coupons: 10
    )
    token = JWT.encode(
      { user_id: user_no_chat.id, email: user_no_chat.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )

    post api_v1_chat_start_path,
      params: { user_id: user_no_chat.id },
      headers: { Authorization: "Bearer #{token}" },
      as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /대화 기능을 사용할 수 있는 멤버십이 필요합니다/, json_response["error"]
  end
end

