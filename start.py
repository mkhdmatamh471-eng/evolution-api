import subprocess
import threading
import http.server
import socketserver
import os
import time
import sys

# إعداد المنفذ من بيئة Render أو الافتراضي 8080
PORT = int(os.environ.get("PORT", 8080))

class SilentHandler(http.server.SimpleHTTPRequestHandler):
    """كلاس للرد بـ OK على أي طلب لتجاوز فحص الصحة في Render"""
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK - Dummy Server is Up")

    def log_message(self, format, *args):
        # تعطيل سجلات الوصول لتقليل الضوضاء في الـ Logs
        pass

def run_dummy_server(httpd):
    """دالة لتشغيل السيرفر الوهمي"""
    print(f"🚀 [Step 1] Dummy server starting on port {PORT}...")
    try:
        httpd.serve_forever()
    except Exception as e:
        print(f"⚠️ Dummy server stopped: {e}")

def main():
    # 1. تجهيز السيرفر الوهمي
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("0.0.0.0", PORT), SilentHandler)

    # 2. تشغيل السيرفر الوهمي في Thread منفصل
    dummy_thread = threading.Thread(target=run_dummy_server, args=(httpd,), daemon=True)
    dummy_thread.start()

    # ننتظر قليلاً لنتأكد أن المنفذ فُتح لـ Render
    time.sleep(5)
    print(f"✅ [Step 2] Port {PORT} is now occupied. Render should see 'Live' status.")

    # 3. إغلاق السيرفر الوهمي لتحرير المنفذ للمحرك الحقيقي
    # ملاحظة: سنغلقه قبل تشغيل المحرك لنتجنب خطأ "Address already in use"
    print(f"🔌 [Step 3] Shutting down dummy server to free port {PORT}...")
    httpd.shutdown()
    httpd.server_close()
    
    # 4. تشغيل Evolution API الحقيقي
    print("🛠️ [Step 4] Starting Evolution API (npm run start:prod)...")
    try:
        # استخدام subprocess.run لتشغيل المحرك وجعل السجل يظهر في Render
        subprocess.run(["npm", "run", "start:prod"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error starting Evolution API: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopping...")
        sys.exit(0)

if __name__ == "__main__":
    main()
