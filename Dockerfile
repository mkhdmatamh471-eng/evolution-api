FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

# ... (نفس الجزء العلوي الخاص بـ builder يبقى كما هو) ...

FROM node:24-alpine AS final

# إضافة python3 لتشغيل سيرفر الوهمي
RUN apk update && \
    apk add tzdata ffmpeg bash openssl python3

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

# ... (الجزء العلوي كما هو) ...

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

# توليد عميل بريزما (Prisma Client) أثناء البناء
RUN npx prisma generate

COPY ./Docker ./Docker
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

# --- المرحلة النهائية ---
FROM node:24-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl python3

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

# نسخ الملفات الضرورية بما فيها مجلد prisma
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/start.py ./start.py

EXPOSE 8080

# تحديث ENTRYPOINT لتنفيذ الهجرة قبل تشغيل السيرفر
# هذا الأمر سيجعل الحاوية تنتظر إنشاء الجداول قبل البدء
ENTRYPOINT ["sh", "-c", "npx prisma migrate deploy && python3 start.py"]