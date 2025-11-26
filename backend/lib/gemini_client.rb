# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Google Gemini API 클라이언트
class GeminiClient
  DEFAULT_MODEL = 'gemini-2.5-flash-lite'
  LITE_MODEL = 'gemini-2.5-flash-lite'

  def api_url_for(model)
    "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent"
  end

  def stream_api_url_for(model)
    "https://generativelanguage.googleapis.com/v1beta/models/#{model}:streamGenerateContent"
  end
  
  def initialize(api_key = nil, model: nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    raise 'GEMINI_API_KEY is not set' if @api_key.nil? || @api_key.empty?
    @model = (model || ENV['GEMINI_MODEL'] || DEFAULT_MODEL).strip
  end

  # 채팅 메시지를 전송하고 AI 응답을 받습니다
  # @param messages [Array<Hash>] 메시지 배열 [{ role: 'user', content: '...' }, ...]
  # @return [String] AI 응답 텍스트
  def chat(messages, gen_options: {})
    payload = build_payload(messages, gen_options)
    
    with_retries do
      response = make_request(payload)
      extract_text_from_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "Gemini API Error: #{e.message}"
    raise "AI 응답 생성 중 오류가 발생했습니다: #{e.message}"
  end

  # 스트리밍으로 채팅 응답을 받습니다
  # @param messages [Array<Hash>] 메시지 배열
  # @param block [Proc] 각 청크를 받을 때 실행할 블록
  def chat_stream(messages, gen_options: {}, &block)
    payload = build_payload(messages, gen_options)
    
    with_retries do
      make_stream_request(payload, &block)
    end
  rescue StandardError => e
    Rails.logger.error "Gemini Streaming API Error: #{e.message}"
    raise "AI 스트리밍 응답 생성 중 오류가 발생했습니다: #{e.message}"
  end

  private

  # OpenAI 스타일 role을 Gemini 스타일로 변환
  def convert_role(role)
    case role.to_s
    when 'assistant'
      'model'
    when 'user'
      'user'
    else
      'user'
    end
  end

  def build_payload(messages, gen_options = {})
    # Gemini API 형식으로 변환
    contents = messages.map do |msg|
      {
        role: convert_role(msg[:role]),
        parts: [{ text: msg[:content] }]
      }
    end

    base = {
      contents: contents,
      generationConfig: {
        temperature: 0.5,
        topK: 30,
        topP: 0.9,
        maxOutputTokens: 500
      },
      safetySettings: [
        {
          category: "HARM_CATEGORY_HARASSMENT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          category: "HARM_CATEGORY_HATE_SPEECH",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          category: "HARM_CATEGORY_DANGEROUS_CONTENT",
          threshold: "BLOCK_MEDIUM_AND_ABOVE"
        }
      ]
    }

    # 옵션 덮어쓰기 (요청별 커스터마이즈)
    if gen_options.is_a?(Hash) && gen_options[:generationConfig].is_a?(Hash)
      base[:generationConfig].merge!(gen_options[:generationConfig])
    end

    base
  end

  def make_request(payload)
    uri = URI.parse("#{api_url_for(@model)}?key=#{@api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      error_body = JSON.parse(response.body) rescue {}
      error_message = error_body.dig('error', 'message') || response.message
      raise "API 요청 실패: #{error_message}"
    end

    JSON.parse(response.body)
  end

  def extract_text_from_response(response)
    # Gemini API 응답 구조: response['candidates'][0]['content']['parts'][0]['text']
    candidates = response['candidates']
    return '응답을 생성할 수 없습니다.' if candidates.nil? || candidates.empty?

    first_candidate = candidates[0]
    content = first_candidate.dig('content', 'parts', 0, 'text')
    
    content || '응답을 생성할 수 없습니다.'
  end

  def make_stream_request(payload, &block)
    uri = URI.parse("#{stream_api_url_for(@model)}?key=#{@api_key}&alt=sse")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30  # 60초에서 30초로 단축

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    chunk_count = 0
    start_time = Time.current

    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        error_body = JSON.parse(response.body) rescue {}
        error_message = error_body.dig('error', 'message') || response.message
        raise "API 요청 실패: #{error_message}"
      end

      buffer = ""
      response.read_body do |chunk|
        buffer += chunk
        
        # SSE 형식 파싱: "data: {...}\n\n"
        while buffer.include?("\n\n")
          line_end = buffer.index("\n\n")
          line = buffer[0...line_end].strip
          buffer = buffer[(line_end + 2)..-1]
          
          next if line.empty?
          
          if line.start_with?("data: ")
            json_str = line[6..-1]
            next if json_str.strip.empty?
            
            begin
              data = JSON.parse(json_str)
              text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
              if text && !text.empty?
                chunk_count += 1
                Rails.logger.debug "[Gemini] chunk=#{text[0,80]}#{text.length > 80 ? '...' : ''}"
                block.call(text)
              end
            rescue JSON::ParserError => e
              Rails.logger.warn "JSON 파싱 실패: #{e.message}"
            end
          end
        end
      end

      # 빈 응답 체크
      elapsed = Time.current - start_time
      if chunk_count == 0
        Rails.logger.warn "[Gemini] 빈 응답 감지 - #{elapsed.round(2)}초 소요, 재시도 필요"
        raise "Gemini에서 빈 응답을 받았습니다. 재시도가 필요합니다."
      else
        Rails.logger.info "[Gemini] 총 #{chunk_count}개 청크 수신 완료 - #{elapsed.round(2)}초 소요"
      end
    end
  end

  # 일시적 오류(과부하/429/5xx/빈응답)에 대해 지수 백오프로 재시도
  def with_retries(max_attempts: 3, base_sleep: 0.8)
    attempt = 0
    begin
      attempt += 1
      yield
    rescue StandardError => e
      message = e.message.to_s
      retryable = message.include?("overloaded") || 
                  message.include?("429") || 
                  message.match?(/5\d\d/) ||
                  message.include?("빈 응답")
      
      if retryable && attempt < max_attempts
        sleep_time = base_sleep * (2 ** (attempt - 1)) + rand * 0.2
        Rails.logger.warn "[Gemini] retry #{attempt}/#{max_attempts - 1} after #{sleep_time.round(2)}s due to: #{message}"
        sleep sleep_time
        retry
      end

      # 최대 재시도 실패 시 경량 모델로 1회 폴백
      if retryable && @model != LITE_MODEL
        Rails.logger.warn "[Gemini] 경량 모델로 폴백 시도: #{@model} -> #{LITE_MODEL}"
        @model = LITE_MODEL
        attempt = 0
        retry
      end
      raise
    end
  end
end

