require_relative '../../../../lib/gemini_client'
require_relative '../../../../lib/system_prompts'

module Api
  module V1
    class ChatController < ApplicationController
      include Authenticatable
      
      before_action :authenticate_user!
      
      # POST /api/v1/chat/message
      # AI와 대화를 주고받습니다
      def message
        user = User.find(params[:user_id])
        messages = params[:messages] || []
        
        # 메시지 유효성 검사
        if messages.empty?
          return render_error('메시지가 비어있습니다.', status: :bad_request)
        end

        # 대화 기능이 있는지 확인
        unless user.has_feature?(FeatureNames::CHAT)
          return render_error('대화 기능을 사용할 수 있는 멤버십이 필요합니다.', status: :forbidden)
        end

        # 쿠폰 차감은 start API에서 이미 처리되었으므로 여기서는 확인만
        if user.chat_coupons.nil? || user.chat_coupons <= 0
          return render_error('남은 채팅 쿠폰이 없습니다. 멤버십을 구매해주세요.', status: :forbidden)
        end

        begin
          # Gemini API 호출
          gemini_client = GeminiClient.new
          
          # 시스템 프롬프트 + 실제 메시지 (최근 대화만 사용해 지연 단축)
          converted_messages = messages.last(4).map do |msg|
            {
              role: msg[:role] || msg['role'],
              content: msg[:content] || msg['content']
            }
          end
          
          full_messages = SystemPrompts.tutor_messages + converted_messages
          
          ai_response = gemini_client.chat(full_messages)
          
          render json: {
            response: ai_response,
            remaining_chat_coupons: user.chat_coupons
          }, status: :ok
          
        rescue StandardError => e
          Rails.logger.error "Chat error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          render json: { 
            error: "AI 응답 생성 중 오류가 발생했습니다.",
            details: e.message 
          }, status: :internal_server_error
        end
      end
      
      # POST /api/v1/chat/message_stream
      # AI와 대화를 주고받습니다 (스트리밍)
      def message_stream
        user = User.find(params[:user_id])
        messages = params[:messages] || []
        
        # 메시지 유효성 검사
        if messages.empty?
          return render_error('메시지가 비어있습니다.', status: :bad_request)
        end

        # 대화 기능이 있는지 확인
        unless user.has_feature?(FeatureNames::CHAT)
          return render_error('대화 기능을 사용할 수 있는 멤버십이 필요합니다.', status: :forbidden)
        end

        # 쿠폰 확인
        if user.chat_coupons.nil? || user.chat_coupons <= 0
          return render json: { 
            error: '남은 채팅 쿠폰이 없습니다. 멤버십을 구매해주세요.' 
          }, status: :forbidden
        end

        # SSE 헤더 설정
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        response.headers['Connection'] = 'keep-alive'

        begin
          # Gemini API 호출
          gemini_client = GeminiClient.new
          
          # 시스템 프롬프트 + 실제 메시지
          converted_messages = messages.map do |msg|
            {
              role: msg[:role] || msg['role'],
              content: msg[:content] || msg['content']
            }
          end
          
          full_messages = SystemPrompts.tutor_messages + converted_messages
          
          # 스트리밍 시작 신호 (클라이언트가 즉시 수신 여부 확인 가능)
          Rails.logger.info "[ChatStream] SSE start user=#{user.id}"
          response.stream.write("data: #{ { type: 'start' }.to_json }\n\n")

          # 스트리밍 시도
          begin
            gemini_client.chat_stream(full_messages, gen_options: { generationConfig: { maxOutputTokens: 400, temperature: 0.5 } }) do |chunk|
              Rails.logger.debug "[ChatStream] SSE chunk user=#{user.id} size=#{chunk.to_s.bytesize}"
              sse_data = {
                type: 'chunk',
                content: chunk
              }
              response.stream.write("data: #{sse_data.to_json}\n\n")
            end
          rescue => stream_error
            Rails.logger.warn "[ChatStream] 스트리밍 실패, 일반 API로 fallback: #{stream_error.message}"
            
            # 일반 채팅 API로 fallback (재시도 포함)
            begin
              fallback_response = gemini_client.chat(full_messages, gen_options: { generationConfig: { maxOutputTokens: 350, temperature: 0.5 } })
              Rails.logger.info "[ChatStream] Fallback 응답 수신: #{fallback_response[0,100]}..."
              
              # fallback 응답을 청크로 나누어 전송
              chunk_size = 30
              fallback_response.chars.each_slice(chunk_size) do |chunk|
                sse_data = {
                  type: 'chunk',
                  content: chunk.join
                }
                response.stream.write("data: #{sse_data.to_json}\n\n")
              end
            rescue => fallback_error
              Rails.logger.error "[ChatStream] Fallback도 실패: #{fallback_error.message}"
              error_data = {
                type: 'error',
                error: 'Gemini API가 일시적으로 과부하 상태입니다. 잠시 후 다시 시도해주세요.',
                details: fallback_error.message
              }
              response.stream.write("data: #{error_data.to_json}\n\n")
              raise fallback_error
            end
          end
          
          # 완료 메시지
          final_data = {
            type: 'done',
            remaining_chat_coupons: user.chat_coupons
          }
          response.stream.write("data: #{final_data.to_json}\n\n")
          Rails.logger.info "[ChatStream] SSE done user=#{user.id}"
          
        rescue StandardError => e
          Rails.logger.error "Chat streaming error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          error_data = {
            type: 'error',
            error: 'AI 응답 생성 중 오류가 발생했습니다.',
            details: e.message
          }
          response.stream.write("data: #{error_data.to_json}\n\n")
        ensure
          response.stream.close
        end
      end
      
      # POST /api/v1/chat/start
      # 채팅 세션 시작 (쿠폰 차감)
      def start
        user = User.find(params[:user_id])
        idempotency_key = params[:idempotency_key].presence
        
        # 대화 기능이 있는지 확인
        unless user.has_feature?('대화')
          return render json: { 
            error: '대화 기능을 사용할 수 있는 멤버십이 필요합니다.' 
          }, status: :forbidden
        end

        # 채팅 쿠폰 확인 및 차감
        if user.chat_coupons.nil? || user.chat_coupons <= 0
          return render_error('남은 채팅 쿠폰이 없습니다. 멤버십을 구매해주세요.', status: :forbidden)
        end

        # Idempotency: 같은 키로 중복 요청 시 재차감 방지 (5분 TTL)
        if idempotency_key
          cache_key = "chat_start:#{user.id}:#{idempotency_key}"
          already_processed = Rails.cache.read(cache_key)
          
          if already_processed
            Rails.logger.info "[ChatStart] 중복 요청 무시: user=#{user.id}, key=#{idempotency_key[0,20]}..."
            return render json: {
              message: '채팅 세션이 이미 시작되었습니다.',
              remaining_chat_coupons: user.chat_coupons
            }, status: :ok
          end
          
          # 차감 후 캐시에 저장
          user.decrement!(:chat_coupons)
          Rails.cache.write(cache_key, true, expires_in: 5.minutes)
        else
          # 키가 없으면 일반 로직 (하위호환)
          user.decrement!(:chat_coupons)
        end
        
        render json: {
          message: '채팅 세션이 시작되었습니다.',
          remaining_chat_coupons: user.chat_coupons
        }, status: :ok
        
      rescue ActiveRecord::RecordNotFound
        render_error('사용자를 찾을 수 없습니다.', status: :not_found)
      rescue StandardError => e
        Rails.logger.error "Chat start error: #{e.message}"
        render_error('채팅 시작 중 오류가 발생했습니다.', details: e.message, status: :internal_server_error)
      end
    end
  end
end

