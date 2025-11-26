require "test_helper"

class Api::V1::ErrorFormatTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "errfmt@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "payments create without params triggers unified parameter error format" do
    post api_v1_payments_path,
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json.key?("error"), "expected error key"
    assert json.key?("details"), "expected details key"
  end

  test "memberships destroy returns not found error format for invalid id" do
    delete api_v1_membership_path(-1),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal 'Membership not found', json['error']
  end
end


