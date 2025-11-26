import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000/api/v1';

// Axios 인스턴스 생성
const chatApi = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터 - 토큰 자동 추가
chatApi.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface SendMessageRequest {
  user_id: number;
  messages: ChatMessage[];
}

export interface SendMessageResponse {
  response: string;
  remaining_chat_coupons: number;
}

export interface StartChatRequest {
  user_id: number;
  idempotency_key?: string;
}

export interface StartChatResponse {
  message: string;
  remaining_chat_coupons: number;
}

// 채팅 세션 시작
export const startChatSession = async (userId: number, idempotencyKey?: string): Promise<StartChatResponse> => {
  try {
    // 전달된 키가 없으면 생성 (하위호환)
    const key = idempotencyKey || `${userId}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const response = await chatApi.post<StartChatResponse>('/chat/start', {
      user_id: userId,
      idempotency_key: key
    });
    return response.data;
  } catch (error: any) {
    const msg = error.response?.data?.error || '채팅 세션을 시작할 수 없습니다.';
    throw new Error(msg);
  }
};

// AI에게 메시지 전송
export const sendMessage = async (userId: number, messages: ChatMessage[]): Promise<SendMessageResponse> => {
  try {
    const response = await chatApi.post<SendMessageResponse>('/chat/message', {
      user_id: userId,
      messages: messages
    });
    return response.data;
  } catch (error: any) {
    const msg = error.response?.data?.error || 'AI 응답을 받을 수 없습니다.';
    throw new Error(msg);
  }
};

// 스트리밍으로 AI 메시지 전송
export const sendMessageStream = async (
  userId: number,
  messages: ChatMessage[],
  onChunk: (chunk: string) => void,
  onDone: (remainingCoupons: number) => void,
  onError: (error: string) => void
): Promise<void> => {
  try {
    const token = localStorage.getItem('token');
    const controller = new AbortController();
    const response = await fetch(`${API_BASE_URL}/chat/message_stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        ...(token && { Authorization: `Bearer ${token}` })
      },
      body: JSON.stringify({
        user_id: userId,
        messages: messages
      }),
      signal: controller.signal
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || 'AI 응답을 받을 수 없습니다.');
    }

    const reader = response.body?.getReader();
    if (!reader) {
      throw new Error('스트림을 읽을 수 없습니다.');
    }

    const decoder = new TextDecoder();
    let buffer = '';
    let gotFirstEvent = false;

    // 첫 이벤트 타임아웃(15초)
    const startTimeout = setTimeout(() => {
      if (!gotFirstEvent) {
        controller.abort();
        onError('응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.');
      }
    }, 15000);

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      // CRLF(\r\n)와 LF(\n) 모두 처리: 빈 줄 두 개로 이벤트 경계 구분
      const delimiterRegex = /\r?\n\r?\n/;
      const parts = buffer.split(delimiterRegex);
      buffer = parts.pop() || '';

      for (const raw of parts) {
        const line = raw.replace(/\r/g, '');
        if (!line.startsWith('data: ')) continue;
        const jsonStr = line.slice(6);
        console.log('SSE 데이터 수신:', jsonStr); // 디버깅용 로그
        try {
          const data = JSON.parse(jsonStr);
          console.log('파싱된 데이터:', data); // 디버깅용 로그
          gotFirstEvent = true;
          if (startTimeout) clearTimeout(startTimeout);
          if (data.type === 'chunk') {
            console.log('청크 내용:', data.content); // 디버깅용 로그
            onChunk(data.content);
          } else if (data.type === 'done') {
            onDone(data.remaining_chat_coupons);
          } else if (data.type === 'error') {
            onError(data.error);
          } else if (data.type === 'start') {
            console.log('스트리밍 시작 신호 수신'); // 디버깅용 로그
          }
        } catch (e) {
          console.error('JSON 파싱 실패:', e, '원본:', jsonStr); // 디버깅용 로그
        }
      }
    }
  } catch (error: any) {
    const msg = error.message || 'AI 응답을 받을 수 없습니다.';
    onError(msg);
  }
};

export default chatApi;

