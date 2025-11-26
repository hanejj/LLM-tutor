module Api
    module V1
      class MembershipsController < ApplicationController
        before_action :authenticate_user!, only: [:create, :destroy]
        # GET /api/v1/memberships
        def index
          memberships = Membership.all
          render json: memberships
        end
  
        # POST /api/v1/memberships
        def create
          membership = Membership.new(membership_params)
          if membership.save
            render json: membership, status: :created
          else
            render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
          end
        end
  
        # DELETE /api/v1/memberships/:id
        def destroy
          membership = Membership.find_by(id: params[:id])
          if membership
            if membership.users.exists?
              return render_error('이 멤버십을 사용하는 사용자가 있어 삭제할 수 없습니다.', status: :conflict)
            end
            membership.destroy!
            head :no_content
          else
            render_error('Membership not found', status: :not_found)
          end
        end
  
        private
  
        def membership_params
          params.require(:membership).permit(:name, :features, :expires_at, :coupon_count)
        end
      end
    end
  end
  