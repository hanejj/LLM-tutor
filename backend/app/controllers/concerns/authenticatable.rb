module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    token = extract_token_from_header
    
    if token.blank?
      render json: { message: '인증 토큰이 필요합니다.' }, status: :unauthorized
      return
    end

    begin
      decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
      user_id = decoded_token[0]['user_id']
      @current_user = User.find(user_id)
    rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
      render json: { message: '유효하지 않은 토큰입니다.' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil if auth_header.blank?
    
    # "Bearer <token>" 형식에서 토큰 추출
    auth_header.split(' ').last if auth_header.start_with?('Bearer ')
  end
end
