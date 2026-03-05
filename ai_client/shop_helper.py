"""
商店购买辅助模块 - 解决单位购买意图与实际不符问题

问题描述:
- 测试脚本使用 shop_index 购买单位，但商店内容是随机的
- 导致意图购买A单位，实际购买B单位

解决方案:
- 从观测日志中解析商店内容
- 查找目标单位的正确索引
- 使用 expected_unit_key 参数验证购买
"""

import re
import asyncio
import time
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass


@dataclass
class ShopUnit:
    """商店单位信息"""
    index: int
    unit_key: str
    cost: int


@dataclass
class ShopState:
    """商店状态"""
    units: List[ShopUnit]
    timestamp: float

    def find_unit(self, unit_key: str) -> Optional[ShopUnit]:
        """查找指定单位的索引"""
        for unit in self.units:
            if unit.unit_key == unit_key:
                return unit
        return None

    def get_unit_at(self, index: int) -> Optional[ShopUnit]:
        """获取指定索引的单位"""
        for unit in self.units:
            if unit.index == index:
                return unit
        return None


class ShopHelper:
    """
    商店购买辅助类

    使用示例:
        helper = ShopHelper(send_action_func, get_observations_func)

        # 购买指定单位（自动查找索引）
        success = await helper.buy_unit("wolf", max_refresh=5)

        # 获取当前商店状态
        shop = helper.get_current_shop()
        if shop:
            for unit in shop.units:
                print(f"[{unit.index}] {unit.unit_key} ({unit.cost}金币)")
    """

    # 商店日志解析模式
    SHOP_REFRESH_PATTERN = re.compile(
        r'商店.*?提供[:：]\s*(.+?)(?:\n|$)',
        re.MULTILINE | re.UNICODE
    )

    UNIT_ENTRY_PATTERN = re.compile(
        r'(\w+)[(（](\d+)\s*金?币?[)）]',
        re.UNICODE
    )

    # 购买成功/失败日志模式
    BUY_SUCCESS_PATTERN = re.compile(
        r'购买.*?\s+(\w+).*?(?:成功|放入)',
        re.UNICODE
    )

    BUY_FAIL_PATTERN = re.compile(
        r'(?:购买失败|无法购买|金币不足|商店空位)',
        re.UNICODE
    )

    def __init__(self, send_action_func, get_observations_func, logger=None):
        """
        初始化

        Args:
            send_action_func: 发送动作的异步函数
            get_observations_func: 获取观测日志的异步函数
            logger: 可选的日志函数
        """
        self.send_action = send_action_func
        self.get_observations = get_observations_func
        self.log = logger or print
        self._current_shop: Optional[ShopState] = None
        self._shop_history: List[ShopState] = []

    def _parse_shop_from_observations(self, observations: List[str]) -> Optional[ShopState]:
        """
        从观测日志中解析商店状态

        Args:
            observations: 观测日志列表

        Returns:
            解析出的商店状态，如果没有找到则返回None
        """
        for obs in reversed(observations):
            # 查找商店刷新日志
            match = self.SHOP_REFRESH_PATTERN.search(obs)
            if match:
                shop_content = match.group(1)
                units = []

                # 解析每个单位
                for idx, unit_match in enumerate(self.UNIT_ENTRY_PATTERN.finditer(shop_content)):
                    unit_key = unit_match.group(1)
                    cost = int(unit_match.group(2))
                    units.append(ShopUnit(index=idx, unit_key=unit_key, cost=cost))

                if units:
                    shop = ShopState(units=units, timestamp=time.time())
                    self._current_shop = shop
                    self._shop_history.append(shop)
                    return shop

        return None

    def get_current_shop(self) -> Optional[ShopState]:
        """获取当前商店状态"""
        return self._current_shop

    async def refresh_shop(self, wait_for_observation: bool = True) -> Optional[ShopState]:
        """
        刷新商店

        Args:
            wait_for_observation: 是否等待并解析观测日志

        Returns:
            刷新后的商店状态
        """
        self.log("[ShopHelper] 刷新商店...")
        await self.send_action({"type": "refresh_shop"})

        if wait_for_observation:
            await asyncio.sleep(0.5)
            obs = await self.get_observations()
            shop = self._parse_shop_from_observations(obs)
            if shop:
                self.log(f"[ShopHelper] 商店已刷新: {[f'{u.unit_key}({u.cost})' for u in shop.units]}")
            return shop

        return None

    async def buy_unit(self, unit_key: str, max_refresh: int = 10,
                       auto_deploy: bool = False,
                       deploy_pos: Optional[Tuple[int, int]] = None) -> Dict:
        """
        购买指定单位（自动查找索引，支持刷新）

        Args:
            unit_key: 目标单位key
            max_refresh: 最大刷新次数
            auto_deploy: 是否自动部署
            deploy_pos: 部署位置 (x, y)，如果为None则放入暂存区

        Returns:
            购买结果字典:
            {
                "success": bool,
                "unit_key": str,  # 实际购买的单位
                "shop_index": int,  # 购买的索引
                "refresh_count": int,  # 刷新次数
                "error": str  # 错误信息（如果失败）
            }
        """
        refresh_count = 0

        while refresh_count <= max_refresh:
            # 获取最新观测
            obs = await self.get_observations()
            shop = self._parse_shop_from_observations(obs)

            if not shop:
                # 如果没有商店信息，尝试刷新获取
                if refresh_count == 0:
                    shop = await self.refresh_shop()
                if not shop:
                    return {
                        "success": False,
                        "error": "无法获取商店信息",
                        "refresh_count": refresh_count
                    }

            # 查找目标单位
            target_unit = shop.find_unit(unit_key)

            if target_unit:
                self.log(f"[ShopHelper] 找到目标单位 {unit_key} 在索引 {target_unit.index}")

                # 购买单位（使用expected_unit_key验证）
                result = await self.send_action({
                    "type": "buy_unit",
                    "shop_index": target_unit.index,
                    "expected_unit_key": unit_key
                })

                # 等待并检查购买结果
                await asyncio.sleep(0.3)
                buy_obs = await self.get_observations()

                # 检查购买是否成功
                actual_unit = None
                for obs_entry in buy_obs:
                    match = self.BUY_SUCCESS_PATTERN.search(obs_entry)
                    if match:
                        actual_unit = match.group(1)
                        break

                if actual_unit:
                    if actual_unit == unit_key:
                        self.log(f"[ShopHelper] 成功购买 {unit_key}")

                        # 自动部署
                        if auto_deploy and deploy_pos:
                            await self._deploy_unit(0, deploy_pos)  # 从暂存区0位置部署

                        return {
                            "success": True,
                            "unit_key": actual_unit,
                            "shop_index": target_unit.index,
                            "refresh_count": refresh_count,
                            "error": None
                        }
                    else:
                        self.log(f"[ShopHelper] 警告: 购买了 {actual_unit} 而不是 {unit_key}")
                        return {
                            "success": True,
                            "unit_key": actual_unit,
                            "shop_index": target_unit.index,
                            "refresh_count": refresh_count,
                            "error": f"单位不匹配: 期望 {unit_key}, 实际 {actual_unit}"
                        }
                else:
                    # 检查是否购买失败
                    for obs_entry in buy_obs:
                        if self.BUY_FAIL_PATTERN.search(obs_entry):
                            return {
                                "success": False,
                                "error": "购买失败（金币不足或其他原因）",
                                "refresh_count": refresh_count
                            }

                    # 假设成功但无法确认
                    return {
                        "success": True,
                        "unit_key": unit_key,
                        "shop_index": target_unit.index,
                        "refresh_count": refresh_count,
                        "error": None
                    }

            # 未找到目标单位，刷新商店
            if refresh_count < max_refresh:
                self.log(f"[ShopHelper] 未找到 {unit_key}，刷新商店 ({refresh_count + 1}/{max_refresh})")
                shop = await self.refresh_shop()
                refresh_count += 1
            else:
                break

        return {
            "success": False,
            "error": f"刷新 {max_refresh} 次后仍未找到单位 {unit_key}",
            "refresh_count": refresh_count
        }

    async def _deploy_unit(self, bench_pos: int, grid_pos: Tuple[int, int]) -> bool:
        """部署单位从暂存区到战场"""
        result = await self.send_action({
            "type": "move_unit",
            "from_zone": "bench",
            "to_zone": "grid",
            "from_pos": bench_pos,
            "to_pos": {"x": grid_pos[0], "y": grid_pos[1]}
        })
        self.log(f"[ShopHelper] 部署单位到 {grid_pos}")
        await asyncio.sleep(0.3)
        return True

    async def buy_any_unit(self, preferred_faction: Optional[str] = None) -> Dict:
        """
        购买任意可用单位（用于初始填充）

        Args:
            preferred_faction: 优先选择的阵营（可选）

        Returns:
            购买结果
        """
        obs = await self.get_observations()
        shop = self._parse_shop_from_observations(obs)

        if not shop or not shop.units:
            return {"success": False, "error": "商店为空"}

        # 选择第一个单位
        target = shop.units[0]

        result = await self.send_action({
            "type": "buy_unit",
            "shop_index": target.index,
            "expected_unit_key": target.unit_key
        })

        await asyncio.sleep(0.3)

        return {
            "success": True,
            "unit_key": target.unit_key,
            "shop_index": target.index,
            "cost": target.cost
        }


# 便捷函数，用于快速集成到现有测试脚本
async def buy_unit_with_retry(send_action, get_observations, unit_key: str,
                               max_refresh: int = 10, logger=None) -> bool:
    """
    便捷函数: 购买指定单位，支持自动刷新

    Args:
        send_action: 发送动作函数
        get_observations: 获取观测函数
        unit_key: 目标单位key
        max_refresh: 最大刷新次数
        logger: 日志函数

    Returns:
        是否成功购买
    """
    helper = ShopHelper(send_action, get_observations, logger)
    result = await helper.buy_unit(unit_key, max_refresh=max_refresh)
    return result["success"] and result.get("unit_key") == unit_key
