import { useRef, useState, useCallback, useEffect } from 'react';

function splitByLanguage(content: string): { text: string; isEnglish: boolean }[] {
  const parts: { text: string; isEnglish: boolean }[] = [];
  let buffer = '';
  let isEnglish = /[A-Za-z]/.test(content[0] || '');

  for (const ch of content) {
    const nowEnglish = /[A-Za-z]/.test(ch);
    if (nowEnglish !== isEnglish && buffer.length > 0) {
      parts.push({ text: buffer, isEnglish });
      buffer = ch;
      isEnglish = nowEnglish;
    } else {
      buffer += ch;
    }
  }
  if (buffer.length > 0) parts.push({ text: buffer, isEnglish });
  return parts;
}

export function useTTS() {
  const [playingMessageId, setPlayingMessageId] = useState<string | null>(null);
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null);

  const cancelAll = useCallback(() => {
    if (window.speechSynthesis.speaking) {
      window.speechSynthesis.cancel();
    }
    setPlayingMessageId(null);
    utteranceRef.current = null;
  }, []);

  useEffect(() => {
    return () => cancelAll();
  }, [cancelAll]);

  const playMessage = useCallback((messageId: string, content: string, rate: number = 1.0) => {
    if (playingMessageId === messageId) {
      cancelAll();
      return;
    }
    if (window.speechSynthesis.speaking) {
      window.speechSynthesis.cancel();
    }

    const textParts = splitByLanguage(content);
    let currentPartIndex = 0;

    const speakNextPart = () => {
      if (currentPartIndex >= textParts.length) {
        setPlayingMessageId(null);
        utteranceRef.current = null;
        return;
      }

      const part = textParts[currentPartIndex];
      const utterance = new SpeechSynthesisUtterance(part.text);
      utterance.lang = part.isEnglish ? 'en-US' : 'ko-KR';
      utterance.rate = rate;
      utterance.pitch = 1.0;

      const voices = window.speechSynthesis.getVoices();
      if (part.isEnglish) {
        const englishVoice = voices.find(v => v.lang.startsWith('en') && v.name.includes('English'));
        if (englishVoice) utterance.voice = englishVoice;
      } else {
        const koreanVoice = voices.find(v => v.lang.startsWith('ko') && v.name.includes('Korean'));
        if (koreanVoice) utterance.voice = koreanVoice;
      }

      utterance.onstart = () => {
        if (currentPartIndex === 0) {
          setPlayingMessageId(messageId);
        }
      };
      utterance.onend = () => {
        currentPartIndex += 1;
        if (currentPartIndex < textParts.length) {
          setTimeout(speakNextPart, 100);
        } else {
          setPlayingMessageId(null);
          utteranceRef.current = null;
        }
      };
      utterance.onerror = () => {
        setPlayingMessageId(null);
        utteranceRef.current = null;
      };

      utteranceRef.current = utterance;
      window.speechSynthesis.speak(utterance);
    };

    if (window.speechSynthesis.getVoices().length === 0) {
      window.speechSynthesis.addEventListener('voiceschanged', () => {
        speakNextPart();
      }, { once: true });
    } else {
      speakNextPart();
    }
  }, [playingMessageId, cancelAll]);

  return { playingMessageId, playMessage, cancelAll };
}
