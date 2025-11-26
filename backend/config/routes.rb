Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  
  namespace :api do
    namespace :v1 do
      # 인증 관련 라우트
      post '/auth/register', to: 'auth#register'
      post '/auth/login', to: 'auth#login'
      post '/auth/logout', to: 'auth#logout'
      get '/auth/me', to: 'auth#me'
      get '/auth/validate', to: 'auth#validate'
      
      # 결제 관련 라우트
      post '/payments', to: 'payments#create'
      
      # AI 채팅 관련 라우트
      post '/chat/start', to: 'chat#start'
      post '/chat/message', to: 'chat#message'
      post '/chat/message_stream', to: 'chat#message_stream'
      
      # 멤버십 관련 라우트
      resources :memberships, only: [:index, :create, :destroy]
      
      # 사용자 관련 라우트
      resources :users, only: [:index, :show] do
        member do
          post :assign_membership
          delete :remove_membership
          get :membership_status
          post :purchase_membership
          # 기능 사용 가능 여부는 테스트에서 POST로도 호출되는 케이스가 있어 GET/POST 모두 허용
          get :feature_available
          post :feature_available
          post :start_chat
        end
      end
    end
  end
end
