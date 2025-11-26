module Api
    module V1
      # 사용자 관리 컨트롤러
      # 사용자 조회, 멤버십 관리, 결제 처리를 담당합니다.
      class UsersController < ApplicationController
  
        # GET /api/v1/users
        # 전체 사용자 목록 조회 (관리자용)
        def index
          users = User.all.includes(:membership)
          
          render json: users.map { |user|
            {
              id: user.id,
              email: user.email,
              chat_coupons: user.chat_coupons,
              membership: user.membership ? {
                id: user.membership.id,
                name: user.membership.name,
                features: user.membership.features,
                expires_at: user.membership.expires_at
              } : nil
            }
          }, status: :ok
        end
  
        # GET /api/v1/users/:id
        # 특정 사용자 정보 조회
        def show
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user

          render json: UserSerializer.as_json(user), status: :ok
        end

        # POST /api/v1/users/:id/assign_membership
        # 사용자에게 멤버십 부여 (관리자용)
        def assign_membership
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user
  
          membership = Membership.find_by(id: params[:membership_id])
          return render_error('Membership not found', status: :not_found) unless membership
  
          user.membership = membership
          
          # 대화 기능 포함 시 쿠폰 추가 지급: 우선 membership.coupon_count 사용, 없으면 정책값
          if membership.has_feature?(FeatureNames::CHAT)
            coupon_count = (membership.coupon_count || 0)
            if coupon_count <= 0
              coupon_count = MembershipPolicy.coupon_count_for(membership.name)
            end
            user.chat_coupons = (user.chat_coupons || 0) + coupon_count
          end
          
          if user.save
            render json: { message: "Membership assigned successfully", user: UserSerializer.as_json(user) }, status: :ok
          else
            render_error(user.errors.full_messages.join(', '), status: :unprocessable_entity)
          end
        end
  
        # DELETE /api/v1/users/:id/remove_membership
        # 사용자 멤버십 회수 (관리자용)
        def remove_membership
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user
  
          user.membership = nil
          user.chat_coupons = 0  # 멤버십 회수 시 쿠폰도 모두 제거
          if user.save
            render json: { message: "Membership removed successfully", user: user }, status: :ok
          else
            render_error(user.errors.full_messages.join(', '), status: :unprocessable_entity)
          end
        end

        # GET /api/v1/users/:id/membership_status
        # 사용자 멤버십 상태 확인
        def membership_status
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user

          if user.membership.nil?
            render json: { status: "unavailable", reason: "No membership assigned" }, status: :ok
          elsif user.membership.expires_at < Time.current
            render json: { status: "expired", reason: "Membership has expired" }, status: :ok
          else
            render json: {
              status: "available",
              membership: {
                name: user.membership.name,
                features: user.membership.features.split(","),
                expires_at: user.membership.expires_at
              }
            }, status: :ok
          end
        end

        # POST /api/v1/users/:id/purchase_membership
        # 멤버십 구매 처리
        def purchase_membership
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user

          membership = Membership.find_by(id: params[:membership_id])
          return render_error('Membership not found', status: :not_found) unless membership

          # 실제 PG사 연동 대신 mock 처리
          # 실제 서비스에서는 여기에 결제 API 연동이 필요합니다
          user.membership = membership
          
          # 대화 기능 포함 시 쿠폰 추가 지급: 우선 membership.coupon_count 사용, 없으면 정책값
          if membership.has_feature?("대화")
            coupon_count = (membership.coupon_count || 0)
            if coupon_count <= 0
              coupon_count = MembershipPolicy.coupon_count_for(membership.name)
            end
            user.chat_coupons = (user.chat_coupons || 0) + coupon_count
          end

          if user.save
            render json: { message: "Membership successfully purchased!", user: UserSerializer.as_json(user) }, status: :ok
          else
            render_error(user.errors.full_messages.join(', '), status: :unprocessable_entity)
          end
        end
        
        def feature_available
          user = User.find_by(id: params[:id])
          return render json: { status: "unavailable", reason: "User not found" }, status: :ok unless user

          if user.membership.nil?
            return render json: { status: "unavailable", reason: "No membership assigned" }, status: :ok
          end

          if user.membership.expires_at < Time.current
            return render json: { status: "expired", reason: "Membership has expired" }, status: :ok
          end

          feature = params[:feature]
          if feature.blank?
            return render json: { status: "invalid", reason: "No feature specified" }, status: :ok
          end

          available_features = user.membership.features.split(",").map(&:strip)
          unless available_features.include?(feature)
            return render json: { status: "unavailable", reason: "Feature not included in membership" }, status: :ok
          end

          # 대화 기능의 경우 쿠폰 잔여 수량도 함께 확인
          if feature == "대화"
            remaining = user.chat_coupons.to_i
            if remaining <= 0
              return render json: {
                status: "unavailable",
                reason: "No chat coupons available",
                feature: feature,
                remaining_chat_coupons: remaining
              }, status: :ok
            end

            return render json: {
              status: "available",
              feature: feature,
              remaining_chat_coupons: remaining
            }, status: :ok
          end

          render json: { status: "available", feature: feature }, status: :ok
        end

        def start_chat
          user = User.find_by(id: params[:id])
          return render_error('User not found', status: :not_found) unless user

          if user.membership.nil?
            return render_error('No membership assigned', status: :forbidden)
          end

          if user.membership.expires_at < Time.current
            return render_error('Membership has expired', status: :forbidden)
          end

          features = user.membership.features.split(",").map(&:strip)
          unless features.include?(FeatureNames::CHAT)
            return render_error('Membership does not include chat feature', status: :forbidden)
          end

          if user.chat_coupons.nil? || user.chat_coupons <= 0
            return render_error('No chat coupons available', status: :payment_required)
          end

          # 차감
          user.chat_coupons -= 1
          if user.save
            render json: {
              message: "Chat session started",
              remaining_chat_coupons: user.chat_coupons
            }, status: :ok
          else
            render_error(user.errors.full_messages.join(', '), status: :unprocessable_entity)
          end
        end

        private
        
        # 정책은 MembershipPolicy 모듈에서 관리합니다.

      end
    end
  end
  
