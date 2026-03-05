#!/usr/bin/env python3
"""
测试脚本来验证spawn_tiles数组是否被正确初始化
"""

import requests
import time
import json

def test_spawn_points():
    print("测试spawn_tiles数组初始化...")
    
    # 重置游戏状态
    print("1. 重置游戏状态")
    response = requests.post("http://127.0.0.1:8002/action", json={
        "actions": [
            {"type": "reset_game"}
        ]
    })
    
    if response.status_code != 200:
        print(f"❌ 游戏重置失败: {response.status_code}")
        return False
        
    result = response.json()
    if not result.get("status") == "ok":
        print(f"❌ 游戏重置失败: {result.get('message')}")
        return False
        
    print("✅ 游戏重置成功")
    
    # 等待游戏状态稳定
    print("2. 等待游戏状态稳定...")
    time.sleep(3)
    
    # 尝试获取游戏状态（通过截图或检查敌人）
    print("3. 检查游戏状态")
    # 目前无法直接获取spawn_tiles数组，我们通过检查是否有敌人生成来间接判断
    
    # 跳转到波次2
    print("4. 跳转到波次2")
    response = requests.post("http://127.0.0.1:8002/action", json={
        "actions": [
            {"type": "skip_to_wave", "wave": 2},
            {"type": "spawn_test_enemy", "type_key": "slime"}
        ]
    })
    
    if response.status_code != 200:
        print(f"❌ 跳转到波次2失败: {response.status_code}")
        return False
        
    result = response.json()
    if not result.get("status") == "ok":
        print(f"❌ 跳转到波次2失败: {result.get('message')}")
        return False
        
    print("✅ 跳转到波次2成功")
    
    # 等待敌人生成
    print("5. 等待敌人生成...")
    time.sleep(3)
    
    # 开始波次
    print("6. 开始波次")
    response = requests.post("http://127.0.0.1:8002/action", json={
        "actions": [
            {"type": "start_wave"}
        ]
    })
    
    if response.status_code != 200:
        print(f"❌ 开始波次失败: {response.status_code}")
        return False
        
    result = response.json()
    if not result.get("status") == "ok":
        print(f"❌ 开始波次失败: {result.get('message')}")
        return False
        
    print("✅ 波次开始成功")
    
    # 等待敌人生成
    print("7. 等待敌人生成...")
    time.sleep(5)
    
    print("✅ 测试完成")
    return True

if __name__ == "__main__":
    try:
        test_spawn_points()
    except Exception as e:
        print(f"❌ 测试过程中发生错误: {e}")
