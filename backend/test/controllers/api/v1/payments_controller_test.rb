require "test_helper"

class Api::V1::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @membership = Membership.create!(
      name: "프리미엄",
      features: "대화,학습",
      expires_at: 30.days.from_now,
      coupon_count: 30
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "should create payment and assign membership" do
    post api_v1_payments_path,
      params: {
        payment: {
          membership_id: @membership.id,
          amount: 10000,
          payment_method: "card",
          card_number: "4242424242424242",
          expiry_date: "12/30",
          cvv: "123"
        }
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "결제가 완료되었습니다.", json["message"]
    assert_equal @membership.id, json.dig("user", "membership", "id")
    assert_equal 30, json.dig("user", "chat_coupons")
  end

  test "should fail with invalid membership" do
    post api_v1_payments_path,
      params: {
        payment: {
          membership_id: -1,
          amount: 10000,
          payment_method: "card"
        }
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_match /멤버십을 찾을 수 없습니다/, json_response["error"]
  end

  test "should succeed even without optional payment parameters" do
    post api_v1_payments_path,
      params: {
        payment: {
          membership_id: @membership.id,
          card_number: "4242424242424242",
          expiry_date: "12/30",
          cvv: "123"
        }
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "결제가 완료되었습니다.", json["message"]
  end

  test "should require authentication" do
    post api_v1_payments_path,
      params: {
        payment: {
          membership_id: @membership.id,
          amount: 10000,
          payment_method: "card"
        }
      },
      as: :json

    assert_response :unauthorized
  end
end