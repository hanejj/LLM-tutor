import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000/api/v1';

/**
 * 멤버십 관련 API 서비스
 * Axios 인스턴스를 생성하고 토큰을 자동으로 추가합니다.
 */
const membershipApi = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 요청 인터셉터 - 토큰 자동 추가
membershipApi.interceptors.request.use(
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
 * 멤버십 정보 인터페이스
 */
export interface Membership {
  id: number;
  name: string;
  features: string[];
  expires_at: string;
  coupon_count: number;
}

export interface PurchaseMembershipRequest {
  membership_id: number;
}

export interface PurchaseMembershipResponse {
  message: string;
  user: {
    id: number;
    email: string;
    membership: {
      name: string;
      features: string[];
      expires_at: string;
    };
  };
}

/**
 * 멤버십 목록 조회
 * @returns {Promise<Membership[]>} 멤버십 목록
 */
export const getMemberships = async (): Promise<Membership[]> => {
  try {
    const response = await membershipApi.get<Membership[]>('/memberships');
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.message || '멤버십 목록을 가져올 수 없습니다.');
  }
};

/**
 * 멤버십 구매
 * @param userId 사용자 ID
 * @param membershipId 멤버십 ID
 * @returns {Promise<PurchaseMembershipResponse>} 구매 결과
 */
export const purchaseMembership = async (userId: number, membershipId: number): Promise<PurchaseMembershipResponse> => {
  try {
    const response = await membershipApi.post<PurchaseMembershipResponse>(`/users/${userId}/purchase_membership`, {
      membership_id: membershipId
    });
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.error || '멤버십 구매에 실패했습니다.');
  }
};
// 결제 API (PG Mock)
export interface CreatePaymentRequest {
  membership_id: number;
  payment_method?: string; // 'card'
  card_number?: string;
  expiry_date?: string; // MM/YY
  cvv?: string;
}

export interface CreatePaymentResponse {
  message: string;
  payment: {
    id: string;
    amount: number;
    status: string;
    membership_name: string;
  };
  user: {
    id: number;
    email: string;
    membership: {
      id: number;
      name: string;
      features: string[];
      expires_at: string;
    } | null;
    chat_coupons: number;
  };
}

export const createPayment = async (payload: CreatePaymentRequest): Promise<CreatePaymentResponse> => {
  try {
    const response = await membershipApi.post<CreatePaymentResponse>(`/payments`, { payment: payload });
    return response.data;
  } catch (error: any) {
    const msg = error.response?.data?.error || '결제에 실패했습니다.';
    throw new Error(msg);
  }
};

// 사용자 멤버십 상태 조회
export const getMembershipStatus = async (userId: number) => {
  try {
    const response = await membershipApi.get(`/users/${userId}/membership_status`);
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.error || '멤버십 상태를 확인할 수 없습니다.');
  }
};

// 채팅 세션 시작 (권한 확인 및 쿠폰 차감 포함)
export interface StartChatResponse {
  message: string;
  remaining_chat_coupons?: number;
}

export const startChat = async (userId: number): Promise<StartChatResponse> => {
  try {
    const response = await membershipApi.post<StartChatResponse>(`/users/${userId}/start_chat`);
    return response.data;
  } catch (error: any) {
    const msg = error.response?.data?.error || '채팅을 시작할 수 없습니다.';
    throw new Error(msg);
  }
};

export default membershipApi;
