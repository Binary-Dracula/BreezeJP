import os
import boto3
from botocore.exceptions import NoCredentialsError
from concurrent.futures import ThreadPoolExecutor
import threading

# ================= CONFIGURATION =================
# 请替换为你自己的 Cloudflare R2 信息
ACCOUNT_ID = "63faf085916714a6053bb49f729e0a88"
ACCESS_KEY_ID = "c68392bfa1a9b068b9c659a355dd178f"
SECRET_ACCESS_KEY = "1ffb2911c9812fe8308cde089335137835fe58953a409036946fa7f422c30431"
BUCKET_NAME = "breeze-jp"  # 你刚才建的 Bucket 名字

# 本地文件夹路径 (例如: ./breeze_audio_backup/)
# 注意：脚本会递归上传这个文件夹下的所有内容
LOCAL_DIRECTORY = "./files/database/BreezeJP/audio"

# 上传到 Bucket 的目标前缀 (如果你想直接放在根目录，留空 "")
# 例如: 如果文件是 audio/word/a.mp3，且这里留空，Bucket 里就是 audio/word/a.mp3
DESTINATION_PREFIX = "audio"

# 并发线程数 (根据你的网速调整，推荐 10-20)
MAX_WORKERS = 20
# =================================================

# 构造 R2 Endpoint
R2_ENDPOINT_URL = f"https://{ACCOUNT_ID}.r2.cloudflarestorage.com"

# 初始化 S3 客户端
s3_client = boto3.client(
    's3',
    endpoint_url=R2_ENDPOINT_URL,
    aws_access_key_id=ACCESS_KEY_ID,
    aws_secret_access_key=SECRET_ACCESS_KEY
)

# 统计计数器
success_count = 0
fail_count = 0
lock = threading.Lock()

def upload_file(file_info):
    global success_count, fail_count
    local_path, s3_key = file_info

    try:
        # 检查文件是否已存在 (可选，为了速度可以注释掉)
        # s3_client.head_object(Bucket=BUCKET_NAME, Key=s3_key)
        # print(f"Skipping (exists): {s3_key}")
        # return
        
        # 自动判断 Content-Type
        content_type = 'application/octet-stream'
        if s3_key.endswith('.mp3'):
            content_type = 'audio/mpeg'
        elif s3_key.endswith('.wav'):
            content_type = 'audio/wav'

        # 上传
        print(f"Uploading: {s3_key} ...")
        s3_client.upload_file(
            local_path, 
            BUCKET_NAME, 
            s3_key, 
            ExtraArgs={'ContentType': content_type}
        )
        
        with lock:
            success_count += 1
    except Exception as e:
        print(f"❌ Error uploading {local_path}: {e}")
        with lock:
            fail_count += 1

def main():
    files_to_upload = []

    print(f"🔍 Scanning directory: {LOCAL_DIRECTORY}...")
    
    # 遍历本地文件夹
    for root, dirs, files in os.walk(LOCAL_DIRECTORY):
        for filename in files:
            if filename.startswith('.'): # 忽略 .DS_Store 等隐藏文件
                continue
                
            local_path = os.path.join(root, filename)
            
            # 计算相对路径，作为 S3 Key
            relative_path = os.path.relpath(local_path, LOCAL_DIRECTORY)
            
            # 处理 Windows 路径分隔符
            relative_path = relative_path.replace("\\", "/")
            
            s3_key = os.path.join(DESTINATION_PREFIX, relative_path)
            if s3_key.startswith("/"):
                s3_key = s3_key[1:]

            files_to_upload.append((local_path, s3_key))

    total_files = len(files_to_upload)
    
    if total_files == 0:
        print(f"⚠️ No files found in {LOCAL_DIRECTORY}. Check the path.")
        return

    print(f"📦 Found {total_files} files. Starting upload with {MAX_WORKERS} threads...")

    # 使用线程池并发上传
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        executor.map(upload_file, files_to_upload)

    print("\n" + "="*30)
    print(f"🎉 Upload Finished!")
    print(f"✅ Success: {success_count}")
    print(f"❌ Failed:  {fail_count}")
    print("="*30)

if __name__ == "__main__":
    main()
