import subprocess
import threading
import http.server
import socketserver
import os

# 1. دالة لتشغيل سيرفر وهمي بسيط جداً لفتح المنفذ فوراً
def run_dummy_server():
    PORT = int(os.environ.get("PORT", 8080))
    Handler = http.server.SimpleHTTPRequestHandler
    # رد بـ 200 OK على أي طلب لكي يرضى Render
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"🚀 Dummy server started on port {PORT}")
        httpd.serve_forever()

# 2. تشغيل السيرفر الوهمي في "خيط" منفصل (Thread)
threading.Thread(target=run_dummy_server, daemon=True).start()

# 3. الآن تشغيل Evolution API الحقيقي (الأمر الأصلي)
# استبدل هذا بالأمر الذي يشغل Evolution في العادة
print("🛠️ Starting Evolution API in background...")
subprocess.run(["npm", "run", "start:prod"]) 
