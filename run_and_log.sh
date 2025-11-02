#!/bin/bash

# 关闭之前运行的实例
pkill -9 SimpleShot 2>/dev/null

# 运行应用并捕获输出
echo "🚀 启动 SimpleShot..."
/Users/momei/Library/Developer/Xcode/DerivedData/SimpleShot-*/Build/Products/Debug/SimpleShot.app/Contents/MacOS/SimpleShot 2>&1 &

# 等待应用启动
sleep 2

echo "✅ SimpleShot 已启动"
echo "📝 按 Ctrl+C 停止日志监控"
echo ""

# 监控日志
tail -f /dev/null
