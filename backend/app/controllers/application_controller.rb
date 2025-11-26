class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable

  private

  def render_error(message, details: nil, status: :bad_request)
    payload = { error: message }
    payload[:details] = details if details.present?
    render json: payload, status: status
  end

  def render_not_found(error)
    render_error('리소스를 찾을 수 없습니다.', details: error.message, status: :not_found)
  end

  def render_unprocessable(error)
    render_error('요청 파라미터가 올바르지 않습니다.', details: error.message, status: :unprocessable_entity)
  end
end
