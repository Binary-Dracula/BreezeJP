import boto3

# ================= CONFIGURATION =================
ACCOUNT_ID = "63faf085916714a6053bb49f729e0a88"
ACCESS_KEY_ID = "c68392bfa1a9b068b9c659a355dd178f"
SECRET_ACCESS_KEY = "1ffb2911c9812fe8308cde089335137835fe58953a409036946fa7f422c30431"
BUCKET_NAME = "breeze-jp"  # 你刚才建的 Bucket 名字
# =================================================

R2_ENDPOINT_URL = f"https://{ACCOUNT_ID}.r2.cloudflarestorage.com"

s3 = boto3.client(
    's3',
    endpoint_url=R2_ENDPOINT_URL,
    aws_access_key_id=ACCESS_KEY_ID,
    aws_secret_access_key=SECRET_ACCESS_KEY
)

def delete_all_objects(bucket_name):
    print(f"🗑️  Starting cleanup for bucket: {bucket_name}...")
    
    # 循环分页删除，直到删光
    while True:
        # 1. 列出文件
        response = s3.list_objects_v2(Bucket=bucket_name)
        
        if 'Contents' not in response:
            print("✅ Bucket is already empty!")
            break
            
        objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
        
        # 2. 批量删除 (S3 API 限制每次最多 1000 个)
        if objects_to_delete:
            print(f"🔥 Deleting batch of {len(objects_to_delete)} files...")
            s3.delete_objects(
                Bucket=bucket_name,
                Delete={'Objects': objects_to_delete}
            )
        else:
            break

    print("🎉 All files deleted successfully.")

if __name__ == "__main__":
    delete_all_objects(BUCKET_NAME)