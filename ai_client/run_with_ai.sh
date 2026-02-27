#!/bin/bash
# 启动Godot游戏（带图形界面）并运行AI客户端

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Godot AI 游戏启动器 ===${NC}"
echo ""

# 检查Godot
if ! command -v godot &> /dev/null; then
    echo "错误: 未找到Godot，请确保Godot在PATH中"
    exit 1
fi

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到python3"
    exit 1
fi

# 检查websockets
if ! python3 -c "import websockets" 2>/dev/null; then
    echo -e "${YELLOW}安装依赖: pip3 install websockets${NC}"
    pip3 install websockets
fi

echo -e "${BLUE}步骤1: 启动Godot游戏（带图形界面）...${NC}"
echo "游戏将在新窗口中启动"
echo ""

# 后台启动Godot（带图形界面，非headless）
cd /home/zhangzhan/tower
godot --path . &
GODOT_PID=$!

echo -e "${GREEN}Godot PID: $GODOT_PID${NC}"
echo ""

# 等待Godot启动
echo "等待游戏初始化..."
sleep 5

echo -e "${BLUE}步骤2: 启动AI客户端...${NC}"
echo ""

# 切换到ai_client目录并运行
cd /home/zhangzhan/tower/ai_client
python3 example_minimal.py

# AI客户端退出后，询问是否关闭Godot
echo ""
echo -e "${YELLOW}AI客户端已退出${NC}"
read -p "是否关闭Godot游戏? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kill $GODOT_PID 2>/dev/null
    echo "已关闭Godot"
fi
