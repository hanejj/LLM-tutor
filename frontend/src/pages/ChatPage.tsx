import React, { useEffect, useRef, useState } from 'react';
import { useChatStream } from '../hooks/useChatStream';
import { useTTS } from '../hooks/useTTS';
import { getStoredUser } from '../services/authService';
import { sendMessageStream, startChatSession, ChatMessage as ChatMsg } from '../services/chatService';
import { useNavigate } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import './ChatPage.css';

/**
 * 채팅 메시지 인터페이스
 */
interface ChatMessage {
  id: string;
  role: 'assistant' | 'user';
  content: string;
}

/**
 * AI 채팅 페이지 컴포넌트
 * 음성 인식, AI 대화, TTS 기능을 제공합니다.
 */
const ChatPage = () => {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [remainingCoupons, setRemainingCoupons] = useState<number | undefined>(undefined);
  const [isRecording, setIsRecording] = useState<boolean>(false);
  const [transcript, setTranscript] = useState<string>('');
  const [textInput, setTextInput] = useState<string>(''); // 텍스트 입력용 상태
  const { playingMessageId, playMessage, cancelAll } = useTTS();
  const [lastMessageTime, setLastMessageTime] = useState<number>(0);
  const [isAiThinking, setIsAiThinking] = useState<boolean>(false); // AI 응답 대기 상태
  const [requestCount, setRequestCount] = useState<number>(0); // 연속 요청 횟수 (오남용 방지)
  const [recordingStartTime, setRecordingStartTime] = useState<number>(0); // 녹음 시작 시간
  const [ttsRate, setTtsRate] = useState<number>(1.2); // 음성 재생 속도
  // 오디오 관련 refs
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const animationIdRef = useRef<number | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  // TTS는 useTTS 훅에서 관리합니다
  const vadTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const recognitionRef = useRef<any>(null); // Web Speech API 인식 객체
  const sessionStartedRef = useRef<boolean>(false); // 채팅 세션 중복 시작 방지
  const sessionKeyRef = useRef<string>(''); // sessionStorage 키
  const autoSendTimeoutRef = useRef<NodeJS.Timeout | null>(null); // 음성 멈춤 자동 전송
  const { stream } = useChatStream();

  // 초기 진입 시 한 번만 실행: 사용자 확인 및 채팅 세션 시작(쿠폰 1회 차감)
  useEffect(() => {
    const init = async () => {
      if (sessionStartedRef.current) {
        return; // 이미 시작됨
      }
      const user = getStoredUser();
      if (!user || !user.id) {
        navigate('/login');
        return;
      }

      try {
        // 최신 사용자 정보 확인
        const token = localStorage.getItem('token');
        const headers: HeadersInit = token ? { Authorization: `Bearer ${token}` } : {};
        const userRes = await fetch(`http://localhost:3000/api/v1/users/${user.id}`, { headers });
        
        if (!userRes.ok) {
          setError('사용자 정보를 불러올 수 없습니다.');
          setTimeout(() => navigate('/'), 3000);
          return;
        }

        const latestUser = await userRes.json();
        // localStorage 업데이트
        localStorage.setItem('user', JSON.stringify(latestUser));

        // 세션 단위(탭 단위) 가드: 이미 시작한 탭이면 재차감 방지
        sessionKeyRef.current = `chatSessionStarted:${latestUser.id}`;
        const idemKeyStorageKey = `chatIdemKey:${latestUser.id}`;
        // idempotency 키를 먼저 확보(경쟁 방지)
        let idemKey = sessionStorage.getItem(idemKeyStorageKey);
        if (!idemKey) {
          idemKey = `${latestUser.id}-${Math.random().toString(36).slice(2)}-${Date.now()}`;
          sessionStorage.setItem(idemKeyStorageKey, idemKey);
        }

        const alreadyStarted = sessionStorage.getItem(sessionKeyRef.current);
        if (!alreadyStarted) {
          // 선점 플래그 설정(경쟁 상태 방지). 실패 시 롤백.
          sessionStorage.setItem(sessionKeyRef.current, '1');
          try {
            const response = await startChatSession(latestUser.id, idemKey);
            setRemainingCoupons(response.remaining_chat_coupons);
          } catch (e) {
            // 실패 시 플래그 롤백하여 재시도 가능
            sessionStorage.removeItem(sessionKeyRef.current);
            throw e;
          }
        }
        sessionStartedRef.current = true;
        
        // AI 첫 메시지 (주제 선택 유도)
        setMessages([
          {
            id: 'greeting-1',
            role: 'assistant',
            content:
              '안녕하세요! 저는 AI 영어 회화 튜터입니다. 😊\n\n오늘은 어떤 주제로 영어 회화를 연습하고 싶으세요?\n\n📚 추천 주제:\n• 여행 영어 (공항, 호텔, 식당)\n• 비즈니스 영어 (회의, 이메일, 전화)\n• 일상 생활 영어 (쇼핑, 은행, 병원)\n• 면접 영어 (자기소개, 경력 설명)\n• 프리토킹 (자유 주제)\n\n관심 있는 주제를 말씀해주시면, 그 주제로 집중해서 학습을 도와드릴게요!'
          }
        ]);
        setLoading(false);
      } catch (err: any) {
        setError(err.message || '채팅 세션을 시작할 수 없습니다.');
        setLoading(false);
        // 3초 후 홈으로 이동
        setTimeout(() => {
          navigate('/');
        }, 3000);
      }
    };
    void init();
  }, [navigate]);

  // 오남용 방지: 최대 녹음 시간 제한 (5분) - 녹음 상태 변화에만 반응
  useEffect(() => {
    const maxRecordingTime = 5 * 60 * 1000;
    const recordingIntervalId = setInterval(() => {
      if (isRecording && recordingStartTime > 0) {
        const duration = Date.now() - recordingStartTime;
        if (duration > maxRecordingTime) {
          setIsRecording(false);
          setError('최대 녹음 시간(5분)을 초과했습니다. 녹음이 자동 종료되었습니다.');
          setTimeout(() => setError(''), 3000);
        }
      }
    }, 1000);

    return () => clearInterval(recordingIntervalId);
  }, [isRecording, recordingStartTime]);

  useEffect(() => {
    // STT 준비(Web Speech API)
    const SpeechRecognitionImpl = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (SpeechRecognitionImpl) {
      const recognition: any = new SpeechRecognitionImpl();
      recognition.lang = 'ko-KR';
      recognition.interimResults = true;
      recognition.continuous = true;
      recognition.onresult = (event: any) => {
        let interim = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const chunk = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            setTranscript((prev) => (prev ? prev + ' ' : '') + chunk.trim());
            // VAD: 음성이 감지되면 타임아웃 리셋
            if (vadTimeoutRef.current) {
              clearTimeout(vadTimeoutRef.current);
            }
            // 0.8초 이상 추가 입력 없으면 자동 전송 (준 실시간)
            if (autoSendTimeoutRef.current) clearTimeout(autoSendTimeoutRef.current);
            autoSendTimeoutRef.current = setTimeout(() => {
              if (isRecording) {
                void handleFinalizeAnswer();
              }
            }, 800);
          } else {
            interim += chunk;
          }
        }
        // 간단히 인터림은 콘솔로만 확인 가능
      };
      recognition.onerror = () => {
        // STT 오류는 무시하고 녹음 UX만 지속
      };
      recognitionRef.current = recognition;
    }

    // 컴포넌트 언마운트 시 TTS 정리
    return () => {
      cancelAll();
      if (vadTimeoutRef.current) {
        clearTimeout(vadTimeoutRef.current);
      }
    };
  }, []);

  // 음성합성(보이스) 프리로딩으로 첫 재생 지연 최소화
  useEffect(() => {
    try {
      const preloadVoices = () => {
        // 보이스 목록을 한 번 조회하면 브라우저가 로드해둠
        window.speechSynthesis.getVoices();
      };
      if (window.speechSynthesis.getVoices().length === 0) {
        window.speechSynthesis.addEventListener('voiceschanged', preloadVoices, { once: true });
      } else {
        preloadVoices();
      }
    } catch (_) {
      // speechSynthesis 미지원 환경은 무시
    }
  }, []);

  // TTS 재생은 useTTS 훅의 playMessage를 사용합니다

  const drawWaveform = () => {
    const analyser = analyserRef.current;
    const canvas = canvasRef.current;
    if (!analyser || !canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bufferLength = analyser.fftSize;
    const dataArray = new Uint8Array(bufferLength);

    const render = () => {
      analyser.getByteTimeDomainData(dataArray);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#4f46e5';
      ctx.beginPath();
      const sliceWidth = canvas.width / bufferLength;
      let x = 0;
      for (let i = 0; i < bufferLength; i++) {
        const v = dataArray[i] / 128.0;
        const y = (v * canvas.height) / 2;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
        x += sliceWidth;
      }
      ctx.lineTo(canvas.width, canvas.height / 2);
      ctx.stroke();
      animationIdRef.current = requestAnimationFrame(render);
    };
    render();
  };

  const startRecording = async () => {
    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('마이크를 사용할 수 없습니다. 브라우저 권한을 확인해주세요.');
        return;
      }
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;

      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      audioContextRef.current = audioContext;
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 2048;
      source.connect(analyser);
      analyserRef.current = analyser;
      drawWaveform();

      // 브라우저 STT 시작
      try {
        recognitionRef.current?.start();
      } catch (_) {
        // 이미 실행 중이면 start()가 에러를 던질 수 있음
      }

      setIsRecording(true);
      setTranscript('');
      setRecordingStartTime(Date.now()); // 녹음 시작 시간 기록
    } catch (e: any) {
      setError('마이크 접근이 거부되었습니다. 브라우저 설정을 확인해주세요.');
    }
  };

  const stopRecording = async () => {
    // 브라우저 STT 중지
    recognitionRef.current?.stop();

    if (animationIdRef.current) cancelAnimationFrame(animationIdRef.current);
    
    // VAD interval 정리
    if (analyserRef.current && (analyserRef.current as any).vadInterval) {
      clearInterval((analyserRef.current as any).vadInterval);
    }
    if (vadTimeoutRef.current) {
      clearTimeout(vadTimeoutRef.current);
      vadTimeoutRef.current = null;
    }
    
    analyserRef.current?.disconnect();
    audioContextRef.current?.close().catch(() => undefined);
    mediaStreamRef.current?.getTracks().forEach((t) => t.stop());
    mediaStreamRef.current = null;
    audioContextRef.current = null;
    analyserRef.current = null;
    animationIdRef.current = null;
    setIsRecording(false);
    setRecordingStartTime(0); // 녹음 종료 후 길이 체크를 위해 초기화
  };

  // 채팅 종료 후 홈으로 이동
  const handleExitChat = async () => {
    try {
      if (isRecording) {
        await stopRecording();
      }
      cancelAll(); // 재생 중인 음성 정리
    } finally {
      navigate('/');
    }
  };

  // 음성/텍스트 공용: 최종 메시지를 AI에게 전송
  const handleFinalizeAnswer = async (forcedContent?: string) => {
    const now = Date.now();
    
    // 오남용 방지 1: 쿨다운 체크 (3초)
    const cooldownTime = 3000;
    if (now - lastMessageTime < cooldownTime) {
      const remainingTime = Math.ceil((cooldownTime - (now - lastMessageTime)) / 1000);
      setError(`너무 빠른 요청입니다. ${remainingTime}초 후에 다시 시도해주세요.`);
      setTimeout(() => setError(''), 2000);
      return;
    }

    // 오남용 방지 2: 연속 요청 횟수 제한 (1분에 10회)
    const oneMinuteAgo = now - 60000;
    if (lastMessageTime > oneMinuteAgo) {
      const newRequestCount = requestCount + 1;
      setRequestCount(newRequestCount);
      
      if (newRequestCount > 10) {
        setError('요청이 너무 많습니다. 1분 후에 다시 시도해주세요.');
        setTimeout(() => setError(''), 3000);
        return;
      }
    } else {
      // 1분이 지났으면 카운트 리셋
      setRequestCount(1);
    }

    // 오남용 방지 3: 너무 짧은 녹음 방지 (최소 0.5초, 음성 입력에만 적용)
    if (!forcedContent && recordingStartTime > 0) {
      const recordingDuration = now - recordingStartTime;
      if (recordingDuration < 500) {
        setError('너무 짧은 녹음입니다. 최소 0.5초 이상 녹음해주세요.');
        setTimeout(() => setError(''), 2000);
        return;
      }
    }

    // 음성 입력인 경우에만 녹음 종료
    if (isRecording) {
      await stopRecording();
    }

    const rawContent = typeof forcedContent === 'string' ? forcedContent : transcript;
    const content = rawContent.trim();
    
    // 오남용 방지 4: 빈 메시지 방지
    if (!content) {
      setError(forcedContent ? '메시지를 입력해주세요.' : '음성이 인식되지 않았습니다. 다시 시도해주세요.');
      setTimeout(() => setError(''), 2000);
      return;
    }
    
    // 오남용 방지 5: 너무 긴 메시지 방지 (1000자 제한)
    if (content.length > 1000) {
      setError('메시지가 너무 깁니다. 간결하게 말씀해주세요.');
      setTimeout(() => setError(''), 2000);
      return;
    }
    
    const user = getStoredUser();
    if (!user) {
      setError('사용자 정보를 찾을 수 없습니다.');
      return;
    }

    // 사용자 메시지 추가
    const userMessage: ChatMessage = { id: `u-${Date.now()}`, role: 'user', content };
    setMessages((prev) => [...prev, userMessage]);
    setTranscript(''); // 입력 필드 초기화
    setLastMessageTime(now); // 마지막 메시지 시간 업데이트

    // AI 응답 요청을 위한 메시지 배열 생성 (id 제외)
    const apiMessages: ChatMsg[] = [...messages, userMessage].map(msg => ({
      role: msg.role as 'user' | 'assistant',
      content: msg.content
    }));

    // AI 응답 대기 시작 (UX 개선)
    setIsAiThinking(true);

    // 스트리밍 AI 응답을 위한 빈 메시지 생성
    const aiMessageId = `a-${Date.now()}`;
    const aiMessage: ChatMessage = {
      id: aiMessageId,
      role: 'assistant',
      content: ''
    };
    setMessages((prev) => [...prev, aiMessage]);

    // 스트리밍으로 AI API 호출
    await stream(
      user.id,
      apiMessages,
      // onChunk: 각 청크를 받을 때마다 메시지 업데이트
      (chunk: string) => {
        setIsAiThinking(false); // 첫 청크 도착 시 대기 상태 해제
        setMessages((prev) =>
          prev.map((msg) =>
            msg.id === aiMessageId
              ? { ...msg, content: msg.content + chunk }
              : msg
          )
        );
      },
      // onDone: 완료 시 남은 쿠폰 업데이트
      (remainingCoupons: number) => {
        setIsAiThinking(false);
        setRemainingCoupons(remainingCoupons);
      },
      // onError: 에러 발생 시
      (errorMsg: string) => {
        setIsAiThinking(false); // 에러 시에도 대기 상태 해제
        setError(errorMsg);
        // 에러 메시지를 마지막 AI 메시지에 표시
        setMessages((prev) =>
          prev.map((msg) =>
            msg.id === aiMessageId && !msg.content
              ? { ...msg, content: '죄송합니다. 응답 생성 중 오류가 발생했습니다. 다시 시도해주세요.' }
              : msg
          )
        );
      }
    );
  };

  if (loading) {
    return (
      <div className="loading">
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: '2rem', marginBottom: '20px' }}>🤖</div>
          <div style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: '10px' }}>
            AI 튜터를 준비하고 있습니다...
          </div>
          <div style={{ fontSize: '0.9rem', opacity: 0.8 }}>
            권한 확인 및 세션 초기화 중
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="chat-container">
      <div className="chat-card">
        <div className="chat-header">
          <div className="title">🤖 AI 튜터 대화</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            {typeof remainingCoupons !== 'undefined' && (
              <div className="coupon">💬 남은 쿠폰: {remainingCoupons}</div>
            )}
            <button
              type="button"
              onClick={() => void handleExitChat()}
              style={{
                padding: '6px 10px',
                borderRadius: 6,
                border: '1px solid #e5e7eb',
                background: '#fff',
                cursor: 'pointer',
                fontSize: '0.85rem'
              }}
            >
              ← 홈으로 나가기
            </button>
          </div>
        </div>

        {error && <div className="error">{error}</div>}

        <div className="messages">
          {messages.map((m) => (
            <div key={m.id} className={`message ${m.role}`}>
              <div className="bubble">
                {m.content ? (
                  <ReactMarkdown>{m.content}</ReactMarkdown>
                ) : (
                  /* AI 응답 대기 중 애니메이션 */
                  <div className="typing-indicator">
                    <span></span>
                    <span></span>
                    <span></span>
                  </div>
                )}
                {m.content && (
                  <button 
                    className={`play-button ${playingMessageId === m.id ? 'playing' : ''}`}
                  onClick={() => playMessage(m.id, m.content, ttsRate)}
                    title={playingMessageId === m.id ? '정지' : '재생'}
                  >
                    {playingMessageId === m.id ? '⏸️' : '▶️'}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="recorder">
          <canvas ref={canvasRef} className={`waveform ${isRecording ? 'active' : ''}`} width={500} height={64} />
          <div className="controls">
            {!isRecording ? (
              <button className="mic-button" onClick={startRecording}>🎤 말하기 시작</button>
            ) : (
              <button className="mic-button recording" onClick={stopRecording}>⏹ 녹음 정지</button>
            )}
            <button 
              className="finalize-button" 
              onClick={() => void handleFinalizeAnswer()} 
              disabled={!transcript.trim() || isAiThinking}
            >
              {isAiThinking ? '⏳ AI 응답 대기 중...' : '✅ 답변 완료'}
            </button>
          </div>
          <div className="transcript" aria-live="polite">
            {transcript || '🎙️ 녹음을 시작하면 여기에 음성이 텍스트로 변환됩니다.'}
          </div>
        </div>
        {/* 텍스트 입력 컨트롤 */}
        <div className="controls" style={{ marginTop: 8 }}>
          <input
            type="text"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                if (textInput.trim() && !isAiThinking) {
                  void handleFinalizeAnswer(textInput);
                  setTextInput('');
                }
              }
            }}
            placeholder="키보드로도 질문을 입력할 수 있어요."
            style={{ flex: 1, padding: '8px 10px', marginRight: 8 }}
          />
          <button
            className="finalize-button"
            onClick={() => {
              if (!textInput.trim() || isAiThinking) return;
              void handleFinalizeAnswer(textInput);
              setTextInput('');
            }}
            disabled={!textInput.trim() || isAiThinking}
          >
            📩 전송
          </button>
        </div>
        {/* 음성 속도 선택 컨트롤 */}
        <div className="controls" style={{ marginTop: 8 }}>
          <label style={{ marginRight: 8 }}>🔊 재생 속도</label>
          <select
            value={ttsRate}
            onChange={(e) => setTtsRate(Number(e.target.value))}
            style={{ padding: '6px 8px' }}
          >
            <option value={0.8}>0.8x</option>
            <option value={1.0}>1.0x</option>
            <option value={1.2}>1.2x</option>
            <option value={1.5}>1.5x</option>
            <option value={1.8}>1.8x</option>
          </select>
        </div>
      </div>
    </div>
  );
};

export default ChatPage;