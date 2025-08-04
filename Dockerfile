# 멀티 스테이지 빌드
FROM node:latest AS build

WORKDIR /app

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci

# adapter-static 설치
RUN npm install --save-dev @sveltejs/adapter-static 
RUN npm install -g serve

# 소스 코드 복사
COPY . .

# SvelteKit 빌드 (build 폴더 생성)
RUN npm run build

# Production 스테이지
FROM node:latest AS production

WORKDIR /app

# package.json 복사
COPY package*.json ./

# production 의존성만 설치
RUN npm ci --only=production

# 빌드된 파일 복사 (dist가 아닌 build 폴더)
COPY --from=build /app/dist ./dist

# 포트 노출
EXPOSE 5143

# health check
CMD curl -f http://wodydtns.duckdns.org:5143/ || exit 1

# 애플리케이션 실행
CMD ["serve", "-s", "dist", "-l", "5143", "-n"]