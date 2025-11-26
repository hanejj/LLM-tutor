require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with email and password" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should be invalid without email" do
    user = User.new(
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should be invalid with duplicate email" do
    User.create!(
      email: "duplicate@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    user = User.new(
      email: "duplicate@example.com",
      password: "password456",
      password_confirmation: "password456"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "should be invalid with invalid email format" do
    user = User.new(
      email: "invalid-email",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
  end

  test "should check if user has feature" do
    membership = Membership.create!(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: membership
    )
    
    assert user.has_feature?("대화")
    assert_not user.has_feature?("분석")
  end

  test "should return false for has_feature when membership is nil" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    assert_not user.has_feature?("대화")
  end

  test "should return false for has_feature when membership is expired" do
    expired_membership = Membership.create!(
      name: "만료됨",
      features: "대화",
      expires_at: 30.days.from_now
    )
    expired_membership.update_column(:expires_at, 1.day.ago)
    
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: expired_membership
    )
    
    assert_not user.has_feature?("대화")
  end

  test "should check if membership is valid" do
    membership = Membership.create!(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: membership
    )
    
    assert user.membership_valid?
  end

  test "should return false for membership_valid when membership is nil" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    assert_not user.membership_valid?
  end
end
