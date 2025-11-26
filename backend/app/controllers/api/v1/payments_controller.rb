module Api
  module V1
    class PaymentsController < ApplicationController
      before_action :authenticate_user!, only: [:create]

      # POST /api/v1/payments
      def create
        @user = current_user
        membership_id = payment_params[:membership_id]
        
        return render_error('멤버십 ID가 필요합니다.', status: :bad_request) unless membership_id

        membership = Membership.find_by(id: membership_id)
        return render_error('멤버십을 찾을 수 없습니다.', status: :not_found) unless membership

      # Mock 결제 처리 (항상 성공 가정, PG 모의 객체 사용)
      card = {
        number: payment_params[:card_number],
        expiry: payment_params[:expiry_date],
        cvv: payment_params[:cvv]
      }.compact

      begin
        client = PgMockClient.new
        payment_result = client.charge(
          amount: 0,
          card: card,
          metadata: { user_id: @user.id, membership_id: membership.id }
        )
      rescue ArgumentError => e
        return render_error('결제 정보가 올바르지 않습니다.', details: e.message, status: :unprocessable_entity)
      end
      
      # 멤버십 할당
      @user.membership = membership
      
      # 대화 기능 포함 시 쿠폰 지급 (멤버십의 실제 쿠폰 개수 사용)
      if membership.has_feature?(FeatureNames::CHAT)
        coupon_count = membership.coupon_count || 0
        @user.chat_coupons = (@user.chat_coupons || 0) + coupon_count
      end
      
      if @user.save
        render json: {
          message: "결제가 완료되었습니다.",
          payment: {
            id: payment_result[:payment_id],
            amount: payment_result[:amount],
            status: "completed",
            membership_name: membership.name
          },
          user: UserSerializer.as_json(@user)
        }, status: :ok
      else
        render_error('멤버십 할당에 실패했습니다.', details: @user.errors.full_messages, status: :unprocessable_entity)
      end
      end

      private

      def payment_params
        params.require(:payment).permit(:membership_id, :payment_method, :card_number, :expiry_date, :cvv)
      end

    end
  end
end
