import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000/api/v1';

/**
 * 사용자 정보 인터페이스
 */
export interface User {
  id: number;
  email: string;
  chat_coupons: number;
  membership: {
    id: number;
    name: string;
    features: string;
    expires_at: string;
  } | null;
}

/**
 * 사용자 관련 API 서비스
 * Axios 인스턴스를 생성하고 토큰을 자동으로 추가합니다.
 */
const userApi = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터 - 토큰 자동 추가
userApi.interceptors.request.use(
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

/**
 * 최신 사용자 정보를 서버에서 가져오고 localStorage를 업데이트합니다
 */
export const refreshUserData = async (userId: number): Promise<User> => {
  try {
    const response = await userApi.get<User>(`/users/${userId}`);
    const user = response.data;
    
    // localStorage 업데이트
    localStorage.setItem('user', JSON.stringify(user));
    
    return user;
  } catch (error: any) {
    const msg = error.response?.data?.error || '사용자 정보를 불러올 수 없습니다.';
    throw new Error(msg);
  }
};

/**
 * 사용자 목록 조회 (어드민용)
 */
export const getAllUsers = async (): Promise<User[]> => {
  try {
    const response = await userApi.get<User[]>('/users');
    return response.data;
  } catch (error: any) {
    const msg = error.response?.data?.error || '사용자 목록을 불러올 수 없습니다.';
    throw new Error(msg);
  }
};

export default userApi;

