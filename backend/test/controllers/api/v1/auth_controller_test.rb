require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  test "should register new user" do
    assert_difference('User.count', 1) do
      post api_v1_auth_register_path,
        params: {
          user: {
            email: "newuser@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        },
        as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    
    assert_equal "회원가입이 완료되었습니다.", json_response["message"]
    assert_not_nil json_response["token"]
    assert_equal "newuser@example.com", json_response["user"]["email"]
  end

  test "should fail to register with invalid email" do
    post api_v1_auth_register_path,
      params: {
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123"
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "회원가입에 실패했습니다.", json_response["message"]
  end

  test "should fail to register with duplicate email" do
    User.create!(
      email: "duplicate@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post api_v1_auth_register_path,
      params: {
        user: {
          email: "duplicate@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      },
      as: :json

    assert_response :unprocessable_entity
  end

  test "should login with valid credentials" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post api_v1_auth_login_path,
      params: {
        auth: {
          email: "test@example.com",
          password: "password123"
        }
      },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal "로그인에 성공했습니다.", json_response["message"]
    assert_not_nil json_response["token"]
    assert_equal user.email, json_response["user"]["email"]
  end

  test "should fail to login with invalid password" do
    User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post api_v1_auth_login_path,
      params: {
        auth: {
          email: "test@example.com",
          password: "wrongpassword"
        }
      },
      as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal "이메일 또는 비밀번호가 올바르지 않습니다.", json_response["message"]
  end

  test "should fail to login with non-existent email" do
    post api_v1_auth_login_path,
      params: {
        auth: {
          email: "nonexistent@example.com",
          password: "password123"
        }
      },
      as: :json

    assert_response :unauthorized
  end

  test "should validate token and return user info" do
    user = create_test_user

    get api_v1_auth_validate_path,
      headers: auth_headers(user),
      as: :json

    assert_response :success
    assert_equal "유효한 토큰입니다.", json_response["message"]
    assert_equal user.email, json_response["user"]["email"]
  end

  test "should return current user info" do
    user = create_test_user

    get api_v1_auth_me_path,
      headers: auth_headers(user),
      as: :json

    assert_response :success
    assert_equal user.email, json_response["user"]["email"]
  end

  test "should return unauthorized without token for me" do
    get api_v1_auth_me_path, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_match /인증 토큰이 필요/, json_response["message"]
  end

  test "should return unauthorized without token for validate" do
    get api_v1_auth_validate_path, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_match /인증 토큰이 필요/, json_response["message"]
  end
end

