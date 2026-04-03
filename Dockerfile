# --- المرحلة الأولى: البناء (Builder) ---
FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

# نسخ ملفات الاعتمادات
COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

RUN npm ci --silent

# نسخ مجلد البريزما وكامل المشروع
COPY ./prisma ./prisma/
COPY . .

# التعديل الجوهري: تحديد اسم الملف الفعلي الموجود في صورتك
RUN npx prisma generate --schema=./prisma/postgresql-schema.prisma

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*
RUN npm run build

# --- المرحلة الثانية: التشغيل (Final) ---
FROM node:24-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl python3

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# نسخ المخرجات الضرورية فقط
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/start.py ./start.py
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/Docker ./Docker


# إيقاف الريديس لضمان عمل الباركود على الخطة المجانية
ENV REDIS_ENABLED=false
ENV CACHE_REDIS_ENABLED=false

EXPOSE 8080

# تشغيل المزامنة في الخلفية أو بسرعة لفتح المنفذ فوراً
ENTRYPOINT ["sh", "-c", "npx prisma generate --schema=./prisma/postgresql-schema.prisma && npx prisma db push --schema=./prisma/postgresql-schema.prisma --accept-data-loss & python3 start.py"]
