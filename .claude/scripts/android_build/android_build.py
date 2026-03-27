import os
import shutil
import subprocess
import yaml

def get_version():
    with open('pubspec.yaml', 'r') as f:
        config = yaml.safe_load(f)
        return config.get('version', 'unknown')

def build_android():
    version = get_version()
    print(f"检测到版本号: {version}")
    
    # 确保 release 目录存在
    if not os.path.exists('release'):
        os.makedirs('release')
    
    # 执行打包命令
    print("正在开始 Android App Bundle 打包...")
    result = subprocess.run(['flutter', 'build', 'appbundle'], capture_output=True, text=True)
    
    if result.returncode != 0:
        print("打包失败！")
        print(result.stderr)
        return False
    
    # 定义源文件和目标文件
    source_path = 'build/app/outputs/bundle/release/app-release.aab'
    target_filename = f'breeze_jp_v{version}_release.aab'
    target_path = os.path.join('release', target_filename)
    
    # 移动并重命名文件
    if os.path.exists(source_path):
        shutil.copy2(source_path, target_path)
        print(f"打包成功！输出路径: {target_path}")
        return True
    else:
        print(f"找不到生成的 AAB 文件: {source_path}")
        return False

if __name__ == "__main__":
    build_android()
