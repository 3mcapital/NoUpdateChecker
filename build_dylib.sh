#!/bin/bash
# 
# build_dylib.sh
# 編譯 NoUpdateChecker.dylib
# 
# 使用方法: ./build_dylib.sh
# 
# 環境要求: macOS + Xcode Command Line Tools
#

echo "========================================"
echo "NoUpdateChecker.dylib 編譯腳本"
echo "========================================"

# 檢查環境
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ 錯誤: 請在 macOS 上運行此腳本"
    exit 1
fi

# 檢查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 錯誤: 請安裝 Xcode Command Line Tools"
    echo "   運行: xcode-select --install"
    exit 1
fi

# 清理舊文件
rm -rf build
mkdir -p build

echo "📦 開始編譯..."

# 編譯命令
clang -dynamiclib \
    -arch arm64 \
    -arch x86_64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -target-ios-version-min 12.0 \
    -fobjc-arc \
    -framework Foundation \
    -framework UIKit \
    -framework StoreKit \
    -o build/NoUpdateChecker.dylib \
    NoUpdateChecker.m \
    -undefined dynamic_lookup

if [ $? -eq 0 ]; then
    echo "✅ 編譯成功!"
    echo ""
    echo "📁 輸出文件: build/NoUpdateChecker.dylib"
    echo ""
    echo "檔案資訊:"
    ls -lh build/NoUpdateChecker.dylib
    file build/NoUpdateChecker.dylib
    echo ""
    echo "========================================"
    echo "使用方法:"
    echo "========================================"
    echo ""
    echo "方式 1: Frida 注入"
    echo "  frida -U -f com.target.app -l NoUpdateChecker.js"
    echo ""
    echo "方式 2: 直接加載 (需要越獄)"
    echo "  cp build/NoUpdateChecker.dylib /Library/MobileSubstrate/DynamicLibraries/"
    echo "  killall -9 SpringBoard"
    echo ""
else
    echo "❌ 編譯失敗"
    exit 1
fi