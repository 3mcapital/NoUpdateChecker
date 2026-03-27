# NoUpdateChecker

阻止 iOS App 檢查更新的 dylib 插件

## 📦 文件說明

| 文件 | 說明 |
|------|------|
| `NoUpdateChecker.m` | 源代碼 (Theos/Objective-C) |
| `NoUpdateChecker.js` | Frida 腳本 (無需越獄) |
| `build_dylib.sh` | macOS 本地編譯腳本 |

## 🚀 快速開始

### 方法 1: GitHub Actions 自動編譯

1. **Fork 此倉庫**
2. **推送代碼** 或點擊 "Dispatch workflow"
3. **下載 Artifacts** → 獲得 `.dylib` 文件

### 方法 2: 本地編譯 (macOS)

```bash
chmod +x build_dylib.sh
./build_dylib.sh
```

### 方法 3: Frida 注入 (無需越獄)

```bash
frida -U -f com.target.app -l NoUpdateChecker.js
```

## 📱 安裝使用

### 越獄設備
```bash
cp NoUpdateChecker.dylib /Library/MobileSubstrate/DynamicLibraries/
killall -9 SpringBoard
```

### Frida 注入
```bash
# 附加到運行中的 App
frida -U -n "TargetApp" -l NoUpdateChecker.js

# 或啟動時注入
frida -U -f com.target.app -l NoUpdateChecker.js
```

## ⚠️ 警告

- 此工具僅用於學習和研究
- 不要用於盜版或非法修改他人 App
- 使用前請確保遵守當地法律法規

## 📄 License

MIT