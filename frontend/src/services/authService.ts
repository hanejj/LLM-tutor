import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000/api/v1';

// Axios 인스턴스 생성
const authApi = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터 - 토큰 자동 추가
authApi.interceptors.request.use(
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

// 응답 인터셉터 - 토큰 만료 처리
authApi.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // 토큰이 만료되었거나 인증이 실패한 경우
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: {
    id: number;
    email: string;
    membership?: {
      id: number;
      name: string;
      features: string[];
      expires_at: string;
    } | null;
  };
}

export interface RegisterRequest {
  email: string;
  password: string;
  password_confirmation: string;
}

export interface AuthError {
  message: string;
  errors?: Record<string, string[]>;
}

// 로그인 API
export const login = async (credentials: LoginRequest): Promise<LoginResponse> => {
  try {
    const response = await authApi.post<LoginResponse>('/auth/login', {
      auth: credentials
    });
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.message || '로그인에 실패했습니다.');
  }
};

// 회원가입 API
export const register = async (userData: RegisterRequest): Promise<LoginResponse> => {
  try {
    const response = await authApi.post<LoginResponse>('/auth/register', {
      user: userData
    });
    return response.data;
  } catch (error: any) {
    if (error.response?.data?.errors) {
      const errorMessages = Object.values(error.response.data.errors).flat();
      throw new Error(errorMessages.join(', '));
    }
    
    throw new Error(error.response?.data?.message || '회원가입에 실패했습니다.');
  }
};

// 로그아웃 API
export const logout = async (): Promise<void> => {
  try {
    await authApi.post('/auth/logout');
  } finally {
    // 클라이언트 측에서 토큰 제거
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }
};

// 현재 사용자 정보 조회
export const getCurrentUser = async () => {
  try {
    const response = await authApi.get('/auth/me');
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.message || '사용자 정보를 가져올 수 없습니다.');
  }
};

// 토큰 유효성 검사
export const validateToken = async (): Promise<boolean> => {
  try {
    const token = localStorage.getItem('token');
    if (!token) return false;
    
    await authApi.get('/auth/validate');
    return true;
  } catch (error) {
    return false;
  }
};

// 인증 상태 확인
export const isAuthenticated = (): boolean => {
  const token = localStorage.getItem('token');
  return !!token;
};

// 저장된 사용자 정보 가져오기
export const getStoredUser = () => {
  const userStr = localStorage.getItem('user');
  return userStr ? JSON.parse(userStr) : null;
};

export default authApi;
