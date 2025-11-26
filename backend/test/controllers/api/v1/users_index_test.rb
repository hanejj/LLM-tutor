require "test_helper"

class Api::V1::UsersIndexControllerTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    
    @user1 = User.create!(
      email: "user1@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: @membership,
      chat_coupons: 10
    )
    
    @user2 = User.create!(
      email: "user2@example.com",
      password: "password123",
      password_confirmation: "password123",
      chat_coupons: 0
    )
  end

  test "should get users index" do
    get api_v1_users_path, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_operator json_response.length, :>=, 2
    
    # 첫 번째 사용자 확인
    user1_data = json_response.find { |u| u["id"] == @user1.id }
    assert_not_nil user1_data
    assert_equal @user1.email, user1_data["email"]
    assert_equal 10, user1_data["chat_coupons"]
    assert_equal @membership.name, user1_data["membership"]["name"]
    
    # 두 번째 사용자 확인
    user2_data = json_response.find { |u| u["id"] == @user2.id }
    assert_not_nil user2_data
    assert_equal @user2.email, user2_data["email"]
    assert_nil user2_data["membership"]
  end

  test "should return empty array when no users exist" do
    User.destroy_all
    
    get api_v1_users_path, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 0, json_response.length
  end
end

