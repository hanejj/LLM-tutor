# 인증 관련 컨트롤러
# 회원가입, 로그인, 로그아웃, 토큰 검증을 처리합니다.
class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!, only: [:me, :validate, :logout]
  
  # POST /api/v1/auth/register
  # 회원가입 처리
  def register
    ActiveRecord::Base.transaction do
      @user = User.new(user_params)

      # 비밀번호 확인 칸 없이 이메일/비번만 받아 회원 생성
      if @user.save
        # 기본 체험 멤버십 자동 부여 (있을 경우)
        trial = Membership.find_by(name: "체험")
        if trial && @user.membership.nil?
          @user.membership = trial

          # 체험 멤버십의 쿠폰 수(또는 정책 기본값)를 사용해 초기 채팅 쿠폰 지급
          coupon_count = (trial.coupon_count || 0)
          coupon_count = MembershipPolicy.coupon_count_for(trial.name) if coupon_count <= 0
          @user.chat_coupons = coupon_count
          @user.save!
        end

        token = generate_jwt_token(@user)
        render json: {
          message: '회원가입이 완료되었습니다.',
          token: token,
          user: user_response(@user)
        }, status: :created
      else
        render json: {
          message: '회원가입에 실패했습니다.',
          errors: @user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  end

  # POST /api/v1/auth/login
  # 로그인 처리
  def login
    @user = User.find_by(email: login_params[:email])
    if @user&.authenticate(login_params[:password])
      token = generate_jwt_token(@user)
      render json: {
        message: '로그인에 성공했습니다.',
        token: token,
        user: user_response(@user)
      }, status: :ok
    else
      render json: {
        message: '이메일 또는 비밀번호가 올바르지 않습니다.'
      }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/logout
  # 로그아웃 처리
  def logout
    render json: {
      message: '로그아웃되었습니다.'
    }, status: :ok
  end

  # GET /api/v1/auth/me
  # 현재 사용자 정보 조회
  def me
    render json: {
      user: user_response(current_user)
    }, status: :ok
  end

  # GET /api/v1/auth/validate
  # 토큰 유효성 검사
  def validate
    render json: {
      message: '유효한 토큰입니다.',
      user: user_response(current_user)
    }, status: :ok
  end

  private

  # 사용자 등록 파라미터 허용
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  # 로그인 파라미터 허용
  def login_params
    params.require(:auth).permit(:email, :password)
  end

  # JWT 토큰 생성
  # @param user [User] 사용자 객체
  # @return [String] JWT 토큰
  def generate_jwt_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      exp: 24.hours.from_now.to_i
    }
    
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  # 사용자 응답 데이터 포맷팅
  # @param user [User] 사용자 객체
  # @return [Hash] 사용자 정보 해시
  def user_response(user)
    {
      id: user.id,
      email: user.email,
      membership: user.membership ? {
        id: user.membership.id,
        name: user.membership.name,
        features: user.membership.features,
        expires_at: user.membership.expires_at
      } : nil
    }
  end
end
