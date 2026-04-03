# --- المرحلة الأولى: البناء (Builder) ---
FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

# نسخ الملفات الضرورية (تأكد من وجود start.py في مجلد المشروع)
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./start.py ./start.py 
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker

# توليد عميل بريزما (Prisma Client) - خطوة أساسية للبناء
RUN npx prisma generate

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*
RUN ./Docker/scripts/generate_database.sh
RUN npm run build

# --- المرحلة الثانية: التشغيل (Final) ---
FROM node:24-alpine AS final

# إضافة بايثون لتشغيل سيرفرك الخاص
RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl python3

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

# نسخ الملفات من مرحلة builder
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/start.py ./start.py

EXPOSE 8080

# التعديل الجذري: تنفيذ الهجرة (إنشاء الجداول) ثم تشغيل السيرفر
# هذا يضمن أن جدول Instance سيكون موجوداً قبل طلب الباركود
ENTRYPOINT ["sh", "-c", "npx prisma migrate deploy && python3 start.py"]
