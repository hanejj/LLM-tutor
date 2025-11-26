puts "Seeding Memberships..."

# 먼저 User부터 지워야 함 (Membership 참조 중)
User.destroy_all
Membership.destroy_all

# 베이직: 학습 / 30일
basic = Membership.create!(
  name: "베이직",
  features: "학습",
  expires_at: 30.days.from_now,
  coupon_count: 0
)

# 프리미엄: 학습 + 대화 + 분석 / 60일
premium = Membership.create!(
  name: "프리미엄",
  features: "학습,대화,분석",
  expires_at: 60.days.from_now,
  coupon_count: 30
)

# 체험: 대화 / 7일
trial = Membership.create!(
  name: "체험",
  features: "대화",
  expires_at: 7.days.from_now,
  coupon_count: 1
)

puts "Done seeding memberships!"

puts "Seeding Users..."

User.create!(
  email: "user1@example.com",
  password: "password123",
  password_confirmation: "password123",
  membership: basic,
  chat_coupons: 0  
)

User.create!(
  email: "user2@example.com",
  password: "password123",
  password_confirmation: "password123",
  membership: premium,
  chat_coupons: 30
)

User.create!(
  email: "user3@example.com",
  password: "password123",
  password_confirmation: "password123",
  membership: trial,
  chat_coupons: 1
)

User.create!(
  email: "user4@example.com",
  password: "password123",
  password_confirmation: "password123",
  membership: nil  # 멤버십 없는 유저
)

puts "Done seeding users!"

