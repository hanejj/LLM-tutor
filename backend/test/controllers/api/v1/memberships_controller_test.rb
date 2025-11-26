require "test_helper"

class Api::V1::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    @user = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "should get memberships index" do
    get api_v1_memberships_path, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.length >= 1
    assert_includes json.map { |m| m["name"] }, @membership.name
  end

  test "should create membership with valid attributes" do
    assert_difference('Membership.count', 1) do
      post api_v1_memberships_path,
        params: {
          membership: {
            name: "프리미엄",
            features: "대화,학습,분석",
            expires_at: 60.days.from_now
          }
        },
        headers: { Authorization: "Bearer #{@token}" },
        as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "프리미엄", json_response["name"]
    assert_equal "대화,학습,분석", json_response["features"]
  end

  test "should not create membership without name" do
    assert_no_difference('Membership.count') do
      post api_v1_memberships_path,
        params: {
          membership: {
            features: "대화",
            expires_at: 30.days.from_now
          }
        },
        headers: { Authorization: "Bearer #{@token}" },
        as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["errors"], "Name can't be blank"
  end

  test "should not create membership without features" do
    assert_no_difference('Membership.count') do
      post api_v1_memberships_path,
        params: {
          membership: {
            name: "프리미엄",
            expires_at: 30.days.from_now
          }
        },
        headers: { Authorization: "Bearer #{@token}" },
        as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["errors"], "Features can't be blank"
  end

  test "should not create membership with past expires_at" do
    assert_no_difference('Membership.count') do
      post api_v1_memberships_path,
        params: {
          membership: {
            name: "프리미엄",
            features: "대화",
            expires_at: 1.day.ago
          }
        },
        headers: { Authorization: "Bearer #{@token}" },
        as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["errors"], "Expires at 는 과거 날짜일 수 없습니다"
  end

  test "should destroy membership" do
    assert_difference('Membership.count', -1) do
      delete api_v1_membership_path(@membership),
        headers: { Authorization: "Bearer #{@token}" },
        as: :json
    end

    assert_response :no_content
  end

  test "should return not found when destroying non-existent membership" do
    delete api_v1_membership_path(-1),
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :not_found
  end

  test "should require authentication for create" do
    post api_v1_memberships_path,
      params: {
        membership: {
          name: "프리미엄",
          features: "대화",
          expires_at: 30.days.from_now
        }
      },
      as: :json

    assert_response :unauthorized
  end

  test "should require authentication for destroy" do
    delete api_v1_membership_path(@membership), as: :json

    assert_response :unauthorized
  end
end
