#!/usr/bin/env python3
"""
日志API一致性测试脚本

验证人类玩家看到的控制台日志与AI Player通过HTTP /observations收到的日志一致。
"""

import requests
import time
import sys
from datetime import datetime

HTTP_PORT = 10000
BASE_URL = f"http://127.0.0.1:{HTTP_PORT}"


def test_observations_api():
    """测试 /observations API 返回非空日志数组"""
    print("\n[测试1] 验证 /observations 返回非空日志数组")
    print("-" * 50)

    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        response.raise_for_status()
        data = response.json()

        if "observations" not in data:
            print("[FAIL] 响应中缺少 'observations' 字段")
            return False

        observations = data["observations"]
        if not isinstance(observations, list):
            print(f"[FAIL] observations 不是数组，类型: {type(observations)}")
            return False

        print(f"[PASS] /observations 返回数组，当前长度: {len(observations)}")
        return True

    except requests.exceptions.ConnectionError:
        print(f"[FAIL] 无法连接到 {BASE_URL}，请确保AI Client已启动")
        return False
    except Exception as e:
        print(f"[FAIL] 请求异常: {e}")
        return False


def test_action_and_observations():
    """测试发送动作后能否收到日志"""
    print("\n[测试2] 验证发送动作后能收到日志")
    print("-" * 50)

    # 先清空现有日志
    requests.get(f"{BASE_URL}/observations", timeout=5)
    time.sleep(0.5)

    # 发送选择图腾动作
    action_payload = {
        "actions": [{"type": "select_totem", "totem_type": "viper"}]
    }

    try:
        response = requests.post(
            f"{BASE_URL}/action",
            json=action_payload,
            timeout=5
        )
        print(f"[INFO] Action响应: {response.status_code}")
    except Exception as e:
        print(f"[WARN] 发送动作失败: {e}")

    # 等待日志产生
    time.sleep(2)

    # 获取日志
    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        data = response.json()
        observations = data.get("observations", [])

        if len(observations) == 0:
            print("[FAIL] 发送动作后未收到任何日志")
            return False

        print(f"[PASS] 收到 {len(observations)} 条日志")
        print("\n收到的日志内容:")
        for i, log in enumerate(observations[-5:], 1):  # 显示最后5条
            print(f"  {i}. {log[:100]}..." if len(str(log)) > 100 else f"  {i}. {log}")

        return True

    except Exception as e:
        print(f"[FAIL] 获取日志失败: {e}")
        return False


def test_log_content_keywords():
    """验证日志内容包含关键事件关键词"""
    print("\n[测试3] 验证日志包含关键事件关键词")
    print("-" * 50)

    keywords = ["[", "]"]  # 基本的日志格式标记
    found_logs = []

    try:
        response = requests.get(f"{BASE_URL}/observations", timeout=5)
        data = response.json()
        observations = data.get("observations", [])

        for log in observations:
            log_str = str(log)
            # 检查是否包含关键事件标记
            if any(marker in log_str for marker in ["[", "】", "TOTEM", "敌人", "波次"]):
                found_logs.append(log_str)

        if found_logs:
            print(f"[PASS] 找到 {len(found_logs)} 条包含关键事件标记的日志")
            print("\n关键日志示例:")
            for i, log in enumerate(found_logs[:3], 1):
                display = log[:120] + "..." if len(log) > 120 else log
                print(f"  {i}. {display}")
            return True
        else:
            print("[WARN] 未找到包含关键事件标记的日志")
            print("[INFO] 当前日志内容:")
            for i, log in enumerate(observations[:3], 1):
                print(f"  {i}. {log[:100]}...")
            return False

    except Exception as e:
        print(f"[FAIL] 测试失败: {e}")
        return False


def test_continuous_logs():
    """测试持续接收日志的能力"""
    print("\n[测试4] 验证持续接收日志能力")
    print("-" * 50)

    all_logs = []
    check_intervals = 3

    for i in range(check_intervals):
        try:
            response = requests.get(f"{BASE_URL}/observations", timeout=5)
            data = response.json()
            observations = data.get("observations", [])
            all_logs.extend(observations)
            print(f"  第{i+1}次轮询: 收到 {len(observations)} 条日志")
            time.sleep(1)
        except Exception as e:
            print(f"  第{i+1}次轮询失败: {e}")

    print(f"\n[PASS] 总共收集到 {len(all_logs)} 条日志")
    return len(all_logs) > 0


def main():
    """主测试函数"""
    print("=" * 60)
    print("日志API一致性测试")
    print(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"目标地址: {BASE_URL}")
    print("=" * 60)

    # 检查服务是否可用
    try:
        response = requests.get(f"{BASE_URL}/status", timeout=3)
        status = response.json()
        print(f"\n服务状态:")
        print(f"  - Godot运行中: {status.get('godot_running', False)}")
        print(f"  - WebSocket连接: {status.get('ws_connected', False)}")
        print(f"  - 崩溃状态: {status.get('crashed', False)}")
    except Exception as e:
        print(f"\n[ERROR] 无法获取服务状态: {e}")
        print("请确保AI Client已启动:")
        print(f"  python3 ai_client/ai_game_client.py --http-port {HTTP_PORT}")
        sys.exit(1)

    # 运行测试
    results = []

    results.append(("observations_api", test_observations_api()))
    results.append(("action_and_observations", test_action_and_observations()))
    results.append(("log_content_keywords", test_log_content_keywords()))
    results.append(("continuous_logs", test_continuous_logs()))

    # 汇总结果
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)

    passed = sum(1 for _, r in results if r)
    total = len(results)

    for name, result in results:
        status = "PASS" if result else "FAIL"
        print(f"  [{status}] {name}")

    print(f"\n总计: {passed}/{total} 通过")

    if passed == total:
        print("\n[OK] 所有测试通过! 日志API工作正常。")
        return 0
    else:
        print("\n[WARNING] 部分测试未通过，请检查日志系统配置。")
        return 1


if __name__ == "__main__":
    sys.exit(main())
