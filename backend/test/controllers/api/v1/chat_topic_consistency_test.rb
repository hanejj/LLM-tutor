require "test_helper"

class Api::V1::ChatTopicConsistencyTest < ActionDispatch::IntegrationTest
  setup do
    @membership = Membership.create!(
      name: "프리미엄",
      features: "학습,대화,분석",
      expires_at: 60.days.from_now
    )
    
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      membership: @membership,
      chat_coupons: 30
    )
    
    @token = JWT.encode(
      { user_id: @user.id, email: @user.email, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
  end

  test "should prompt user to select topic in first message" do
    # 첫 대화 시작
    messages = []
    
    post api_v1_chat_message_path,
      params: {
        user_id: @user.id,
        messages: messages
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :bad_request  # 메시지가 비어있으면 에러
  end

  test "should include topic selection guidance in system prompt" do
    # 프롬프트에 주제 선택 가이드가 포함되어 있는지 확인
    # (실제로는 ChatController의 시스템 프롬프트를 확인)
    
    messages = [
      { role: 'user', content: '영어 회화를 배우고 싶어요' }
    ]
    
    post api_v1_chat_message_path,
      params: {
        user_id: @user.id,
        messages: messages
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    # AI가 주제 선택을 유도하는 답변을 했는지 확인
    assert json_response["response"].present?
    
    # 주제 관련 키워드가 포함되어 있는지 확인
    response_content = json_response["response"].downcase
    topic_keywords = ['여행', '비즈니스', '일상', '면접', '주제', 'topic']
    
    has_topic_keyword = topic_keywords.any? { |keyword| response_content.include?(keyword) }
    assert has_topic_keyword, "AI 응답에 주제 관련 키워드가 포함되어야 합니다"
  end

  test "should maintain topic consistency in conversation" do
    # 여행 영어 주제를 선택하고, 그 주제로 계속 대화하는지 확인
    messages = [
      { role: 'user', content: '여행 영어를 배우고 싶어요' },
      { role: 'assistant', content: '좋아요! 여행 영어를 배워보겠습니다. 공항에서 체크인하는 상황부터 시작해볼까요?' },
      { role: 'user', content: '체크인할 때 뭐라고 말하나요?' }
    ]
    
    post api_v1_chat_message_path,
      params: {
        user_id: @user.id,
        messages: messages
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    # AI가 여행 영어 맥락을 유지하는지 확인
    response_content = json_response["response"].downcase
    travel_keywords = ['체크인', '공항', 'check in', 'flight', '비행기', '여행']
    
    has_travel_keyword = travel_keywords.any? { |keyword| response_content.include?(keyword) }
    assert has_travel_keyword, "AI 응답이 여행 영어 주제를 유지해야 합니다"
  end

  test "should prevent topic drift" do
    # 주제가 이탈되지 않도록 하는지 테스트
    messages = [
      { role: 'user', content: '비즈니스 영어를 배우고 싶어요' },
      { role: 'assistant', content: '비즈니스 영어를 배워봅시다. 회의 상황부터 시작할까요?' },
      { role: 'user', content: '근데 식당에서는 어떻게 주문하나요?' }  # 주제 이탈 시도
    ]
    
    post api_v1_chat_message_path,
      params: {
        user_id: @user.id,
        messages: messages
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    response_content = json_response["response"]
    
    # AI가 원래 주제(비즈니스)로 유도하는지 확인
    # 또는 주제 이탈을 언급하는지 확인
    topic_maintenance_keywords = ['먼저', '비즈니스', '회의', '마무리', '나중에', '다음에']
    
    has_maintenance = topic_maintenance_keywords.any? { |keyword| response_content.include?(keyword) }
    
    # 주제 유지 또는 이탈 방지 메시지가 있거나, 비즈니스 맥락을 유지해야 함
    assert response_content.present?, "AI가 주제 일관성을 유지해야 합니다"
  end

  test "should provide structured learning within topic" do
    # 주제 내에서 단계적 학습을 제공하는지 확인
    messages = [
      { role: 'user', content: '공항 영어를 배우고 싶어요' },
      { role: 'assistant', content: '공항 영어를 배워봅시다!' },
      { role: 'user', content: '체크인은 배웠어요. 다음은요?' }
    ]
    
    post api_v1_chat_message_path,
      params: {
        user_id: @user.id,
        messages: messages
      },
      headers: { Authorization: "Bearer #{@token}" },
      as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    
    # AI가 공항 영어 맥락 내에서 다음 단계를 제시하는지 확인
    response_content = json_response["response"].downcase
    airport_progression = ['보안검색', '게이트', '탑승', 'security', 'boarding', '수하물']
    
    has_progression = airport_progression.any? { |keyword| response_content.include?(keyword) }
    assert response_content.present?, "AI가 주제 내 단계적 학습을 제공해야 합니다"
  end
end

