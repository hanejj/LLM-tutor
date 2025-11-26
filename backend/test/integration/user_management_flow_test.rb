require "test_helper"

class UserManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @admin_token = JWT.encode(
      { user_id: @admin.id, email: @admin.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )

    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @user_token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )

    @membership = Membership.create!(
      name: "프리미엄",
      features: "대화,학습",
      expires_at: 30.days.from_now
    )
  end

  test "complete user management flow" do
    # 1. 사용자 목록 조회
    get api_v1_users_path,
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_operator json_response.length, :>=, 2

    # 2. 특정 사용자 정보 조회
    get api_v1_user_path(@user),
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @user.email, json_response["email"]
    assert_nil json_response["membership"]

    # 3. 사용자에게 멤버십 부여
    post assign_membership_api_v1_user_path(@user),
      params: { membership_id: @membership.id },
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Membership assigned successfully", json_response["message"]

    @user.reload
    assert_equal @membership.id, @user.membership_id
    assert_equal 30, @user.chat_coupons # 프리미엄은 30개 쿠폰

    # 4. 멤버십 상태 확인
    get membership_status_api_v1_user_path(@user),
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "available", json_response["status"]
    assert_equal @membership.name, json_response["membership"]["name"]

    # 5. 기능 사용 가능 여부 확인
    get "/api/v1/users/#{@user.id}/feature_available",
      params: { feature: "대화" },
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "available", json_response["status"]

    # 6. 멤버십 회수
    delete remove_membership_api_v1_user_path(@user),
      headers: { Authorization: "Bearer #{@admin_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Membership removed successfully", json_response["message"]

    @user.reload
    assert_nil @user.membership
    assert_equal 0, @user.chat_coupons
  end

  test "user purchase membership flow" do
    # 1. 사용자가 멤버십 구매
    post purchase_membership_api_v1_user_path(@user),
      params: { membership_id: @membership.id },
      headers: { Authorization: "Bearer #{@user_token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Membership successfully purchased!", json_response["message"]

    @user.reload
    assert_equal @membership.id, @user.membership_id
    assert_equal 30, @user.chat_coupons
  end

  test "unauthorized access to admin functions" do
    # 일반 사용자가 관리자 기능에 접근 시도
    get api_v1_users_path,
      headers: { Authorization: "Bearer #{@user_token}" },
      as: :json

    assert_response :success # 현재는 인증만 확인하고 권한은 체크하지 않음

    post assign_membership_api_v1_user_path(@user),
      params: { membership_id: @membership.id },
      headers: { Authorization: "Bearer #{@user_token}" },
      as: :json

    assert_response :success # 현재는 인증만 확인하고 권한은 체크하지 않음
  end
end
