require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "프리미엄",
      features: "학습,대화,분석",
      expires_at: 30.days.from_now
    )
    @user = User.create!(
      email: "user@example.com",
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

  test "feature_available returns available for included non-chat feature" do
    get feature_available_api_v1_user_path(@user.id, feature: "학습"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "available", json["status"]
    assert_equal "학습", json["feature"]
  end

  test "feature_available returns unavailable when feature missing" do
    get feature_available_api_v1_user_path(@user.id, feature: "발화"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "unavailable", json["status"]
  end

  test "feature_available returns unavailable when no membership" do
    @user.update!(membership: nil)

    get feature_available_api_v1_user_path(@user.id, feature: "대화"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "unavailable", json["status"]
  end

  test "feature_available returns expired when membership expired" do
    @membership.update!(expires_at: 1.day.ago)

    get feature_available_api_v1_user_path(@user.id, feature: "대화"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "expired", json["status"]
  end

  test "feature_available returns available with remaining coupons for chat" do
    get feature_available_api_v1_user_path(@user.id, feature: "대화"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "available", json["status"]
    assert_equal 2, json["remaining_chat_coupons"]
  end

  test "feature_available returns unavailable for chat when no coupons" do
    @user.update!(chat_coupons: 0)

    get feature_available_api_v1_user_path(@user.id, feature: "대화"),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "unavailable", json["status"]
    assert_equal 0, json["remaining_chat_coupons"]
  end
end

require "test_helper"

class Api::V1::UsersControllerBasicTest < ActionDispatch::IntegrationTest
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
  end

  test "should get user info" do
    get api_v1_user_path(@user), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal @user.id, json_response["id"]
    assert_equal @user.email, json_response["email"]
    assert_equal 10, json_response["chat_coupons"]
    assert_equal @membership.name, json_response["membership"]["name"]
  end

  test "should return not_found for missing user" do
    get api_v1_user_path(-1), as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_match /not found/i, json_response["error"]
  end

  test "should assign membership to user" do
    user_no_membership = User.create!(
      email: "nomembership@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post assign_membership_api_v1_user_path(user_no_membership),
      params: { membership_id: @membership.id },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Membership assigned successfully", json_response["message"]
    
    user_no_membership.reload
    assert_equal @membership.id, user_no_membership.membership_id
    assert_equal 0, user_no_membership.chat_coupons  # 베이직은 쿠폰 없음
  end

  test "should assign membership with coupons for premium" do
    user_no_membership = User.create!(
      email: "nomembership@example.com",
      password: "password123",
      password_confirmation: "password123",
      chat_coupons: 0
    )

    premium = Membership.create!(
      name: "프리미엄",
      features: "대화",
      expires_at: 60.days.from_now
    )

    post assign_membership_api_v1_user_path(user_no_membership),
      params: { membership_id: premium.id },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    user_no_membership.reload
    assert_equal premium.id, user_no_membership.membership_id
    assert_equal 30, user_no_membership.chat_coupons  # 프리미엄은 30개 쿠폰
  end

  test "should add coupons to existing coupons when assigning membership" do
    user_with_coupons = User.create!(
      email: "withcoupons@example.com",
      password: "password123",
      password_confirmation: "password123",
      chat_coupons: 10
    )

    premium = Membership.create!(
      name: "프리미엄",
      features: "대화",
      expires_at: 60.days.from_now
    )

    post assign_membership_api_v1_user_path(user_with_coupons),
      params: { membership_id: premium.id },
      as: :json

    assert_response :success
    
    user_with_coupons.reload
    assert_equal 40, user_with_coupons.chat_coupons  # 기존 10 + 신규 30 = 40
  end

  test "should remove membership from user" do
    delete remove_membership_api_v1_user_path(@user), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Membership removed successfully", json_response["message"]
    
    @user.reload
    assert_nil @user.membership
    assert_equal 0, @user.chat_coupons  # 쿠폰도 0으로 초기화되어야 함
  end

  test "should remove coupons when removing membership" do
    @user.update!(chat_coupons: 50)
    
    delete remove_membership_api_v1_user_path(@user), as: :json

    assert_response :success
    
    @user.reload
    assert_equal 0, @user.chat_coupons
  end

  test "should get membership status" do
    get membership_status_api_v1_user_path(@user), as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal "available", json_response["status"]
    assert_equal @membership.name, json_response["membership"]["name"]
  end

  test "should check feature availability" do
    get "/api/v1/users/#{@user.id}/feature_available",
      params: { feature: "대화" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "available", json_response["status"]
  end

  test "should return unavailable for missing feature" do
    get "/api/v1/users/#{@user.id}/feature_available",
      params: { feature: "분석" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "unavailable", json_response["status"]
  end
end
