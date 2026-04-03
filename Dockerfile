# --- المرحلة الأولى: البناء (Builder) ---
FROM node:24-alpine AS builder

# تثبيت الأدوات الأساسية للبناء
RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

# 1. نسخ ملفات الاعتمادات أولاً (للاستفادة من الكاش)
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./
RUN npm ci --silent

# 2. نسخ الملفات المصدرية وملفات Prisma (ترتيب حاسم)
COPY ./prisma ./prisma
COPY ./src ./src
COPY ./public ./public
COPY ./manager ./manager
COPY ./Docker ./Docker
COPY ./start.py ./start.py
COPY ./runWithProvider.js ./
COPY ./.env.example ./.env

# 3. توليد عميل بريزما (Prisma Client)
RUN npx prisma generate

# 4. تنظيف سكربتات الدوكر وبناء المشروع
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*
RUN ./Docker/scripts/generate_database.sh
RUN npm run build

# --- المرحلة الثانية: التشغيل النهائي (Final) ---
FROM node:24-alpine AS final

# إضافة بايثون لتشغيل سيرفرك
RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl python3

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# نسخ المخرجات من مرحلة البناء فقط
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/start.py ./start.py

EXPOSE 8080

# الحل الجذري: تنفيذ الهجرة لإنشاء الجداول ثم تشغيل بايثون
# هذا يمنع خطأ الـ 500 و "Table public.Instance not found"
ENTRYPOINT ["sh", "-c", "npx prisma migrate deploy && python3 start.py"]
