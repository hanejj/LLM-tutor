require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "should be valid with all required attributes" do
    membership = Membership.new(
      name: "베이직",
      features: "대화",
      expires_at: 30.days.from_now
    )
    assert membership.valid?
  end

  test "should be invalid without name" do
    membership = Membership.new(
      features: "대화",
      expires_at: 30.days.from_now
    )
    assert_not membership.valid?
    assert_includes membership.errors[:name], "can't be blank"
  end

  test "should be invalid without features" do
    membership = Membership.new(
      name: "베이직",
      expires_at: 30.days.from_now
    )
    assert_not membership.valid?
    assert_includes membership.errors[:features], "can't be blank"
  end

  test "should be invalid without expires_at" do
    membership = Membership.new(
      name: "베이직",
      features: "대화"
    )
    assert_not membership.valid?
    assert_includes membership.errors[:expires_at], "can't be blank"
  end

  test "should be invalid with past expires_at on create" do
    membership = Membership.new(
      name: "베이직",
      features: "대화",
      expires_at: 1.day.ago
    )
    assert_not membership.valid?
    assert_includes membership.errors[:expires_at], "는 과거 날짜일 수 없습니다"
  end

  test "should check if membership is active" do
    active_membership = Membership.create!(
      name: "활성",
      features: "대화",
      expires_at: 30.days.from_now
    )
    assert active_membership.active?
  end

  test "should check if membership has specific feature" do
    membership = Membership.create!(
      name: "프리미엄",
      features: "학습,대화,분석",
      expires_at: 30.days.from_now
    )
    
    assert membership.has_feature?("대화")
    assert membership.has_feature?("학습")
    assert membership.has_feature?("분석")
    assert_not membership.has_feature?("없는기능")
  end

  test "should return features as array" do
    membership = Membership.create!(
      name: "프리미엄",
      features: "학습, 대화, 분석",
      expires_at: 30.days.from_now
    )
    
    assert_equal ["학습", "대화", "분석"], membership.features_array
  end
end
