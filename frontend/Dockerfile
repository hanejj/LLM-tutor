FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
# package-lock.json과 실제 의존성이 약간 어긋난 상태이므로 ci 대신 install 사용
RUN npm install

COPY . .

# CRA 개발 서버 포트를 고정 (docker-compose와 연동)
ENV PORT=3001

EXPOSE 3001

# 컨테이너에서는 리눅스 쉘을 사용하므로 start:docker 스크립트를 사용
CMD ["npm", "run", "start:docker"]


