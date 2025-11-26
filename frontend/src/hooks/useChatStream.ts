import { useCallback } from 'react';
import { sendMessageStream } from '../services/chatService';

export function useChatStream() {
  const stream = useCallback(async (
    userId: number,
    messages: { role: 'user' | 'assistant'; content: string }[],
    onChunk: (chunk: string) => void,
    onDone: (remainingCoupons: number) => void,
    onError: (errorMsg: string) => void
  ) => {
    await sendMessageStream(userId, messages, onChunk, onDone, onError);
  }, []);

  return { stream };
}
