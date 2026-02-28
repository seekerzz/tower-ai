#!/usr/bin/env python3
"""
Godot AI 游戏客户端 - 完整实现

使用方法:
    1. 启动 Godot 游戏
    2. python3 ai_game_client.py

依赖:
    pip install websockets
"""

import asyncio
import websockets
import json
import logging
from typing import List, Dict, Optional, Any
from dataclasses import dataclass
from enum import Enum

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class EventType(Enum):
    """游戏事件类型"""
    TOTEM_SELECTION = "TotemSelection"
    TOTEM_SELECTED = "TotemSelected"
    WAVE_STARTED = "WaveStarted"
    WAVE_ENDED = "WaveEnded"
    WAVE_RESET = "WaveReset"
    GAME_OVER = "GameOver"
    BOSS_SPAWNED = "BossSpawned"
    CORE_CRITICAL = "CoreCritical"
    AI_WAKEUP = "AI_Wakeup"
    TEST_EVENT = "TestEvent"


class ActionType(Enum):
    """动作类型"""
    SELECT_TOTEM = "select_totem"
    BUY_UNIT = "buy_unit"
    SELL_UNIT = "sell_unit"
    MOVE_UNIT = "move_unit"
    REFRESH_SHOP = "refresh_shop"
    LOCK_SHOP_SLOT = "lock_shop_slot"
    UNLOCK_SHOP_SLOT = "unlock_shop_slot"
    START_WAVE = "start_wave"
    RETRY_WAVE = "retry_wave"
    RESUME = "resume"
    # 作弊指令
    CHEAT_ADD_GOLD = "cheat_add_gold"
    CHEAT_ADD_MANA = "cheat_add_mana"
    CHEAT_SPAWN_UNIT = "cheat_spawn_unit"
    CHEAT_SET_TIME_SCALE = "cheat_set_time_scale"


@dataclass
class Position:
    """网格位置"""
    x: int
    y: int

    def to_dict(self) -> Dict[str, int]:
        return {"x": self.x, "y": self.y}

    @classmethod
    def from_dict(cls, data: Dict) -> "Position":
        return cls(x=data.get("x", 0), y=data.get("y", 0))


@dataclass
class Unit:
    """单位数据"""
    key: str
    level: int
    grid_pos: Optional[Position]

    @classmethod
    def from_dict(cls, data: Dict) -> Optional["Unit"]:
        if data is None:
            return None
        grid_pos = data.get("grid_pos")
        return cls(
            key=data.get("key", ""),
            level=data.get("level", 1),
            grid_pos=Position.from_dict(grid_pos) if grid_pos else None
        )


@dataclass
class ShopSlot:
    """商店槽位"""
    index: int
    unit_key: Optional[str]
    locked: bool

    @classmethod
    def from_dict(cls, data: Dict) -> "ShopSlot":
        return cls(
            index=data.get("index", 0),
            unit_key=data.get("unit_key"),
            locked=data.get("locked", False)
        )


@dataclass
class BenchSlot:
    """备战区槽位"""
    index: int
    unit: Optional[Unit]

    @classmethod
    def from_dict(cls, data: Dict) -> "BenchSlot":
        return cls(
            index=data.get("index", 0),
            unit=Unit.from_dict(data.get("unit"))
        )


@dataclass
class GridUnit:
    """网格单位"""
    position: Position
    unit: Unit

    @classmethod
    def from_dict(cls, data: Dict) -> "GridUnit":
        return cls(
            position=Position.from_dict(data.get("position", {})),
            unit=Unit.from_dict(data.get("unit"))
        )


@dataclass
class Enemy:
    """敌人数据"""
    type: str
    hp: float
    max_hp: float
    position: Dict[str, float]
    speed: float
    state: str
    debuffs: List[Dict]

    @classmethod
    def from_dict(cls, data: Dict) -> "Enemy":
        return cls(
            type=data.get("type", "unknown"),
            hp=data.get("hp", 0),
            max_hp=data.get("max_hp", 0),
            position=data.get("position", {}),
            speed=data.get("speed", 0),
            state=data.get("state", "unknown"),
            debuffs=data.get("debuffs", [])
        )


@dataclass
class GameState:
    """游戏状态"""
    event: str
    event_data: Dict
    timestamp: float
    wave: int
    gold: int
    mana: float
    max_mana: float
    core_health: float
    max_core_health: float
    is_wave_active: bool
    shop_refresh_cost: int
    shop: List[ShopSlot]
    bench: List[BenchSlot]
    grid: List[GridUnit]
    enemies: List[Enemy]

    @classmethod
    def from_dict(cls, data: Dict) -> "GameState":
        global_data = data.get("global", {})
        board_data = data.get("board", {})

        return cls(
            event=data.get("event", ""),
            event_data=data.get("event_data", {}),
            timestamp=data.get("timestamp", 0),
            wave=global_data.get("wave", 1),
            gold=global_data.get("gold", 0),
            mana=global_data.get("mana", 0),
            max_mana=global_data.get("max_mana", 0),
            core_health=global_data.get("core_health", 0),
            max_core_health=global_data.get("max_core_health", 0),
            is_wave_active=global_data.get("is_wave_active", False),
            shop_refresh_cost=global_data.get("shop_refresh_cost", 10),
            shop=[ShopSlot.from_dict(s) for s in board_data.get("shop", [])],
            bench=[BenchSlot.from_dict(b) for b in board_data.get("bench", [])],
            grid=[GridUnit.from_dict(g) for g in board_data.get("grid", [])],
            enemies=[Enemy.from_dict(e) for e in data.get("enemies", [])]
        )


class ActionBuilder:
    """动作构建器"""

    @staticmethod
    def select_totem(totem_id: str) -> Dict:
        """选择图腾"""
        return {"type": ActionType.SELECT_TOTEM.value, "totem_id": totem_id}

    @staticmethod
    def buy_unit(shop_index: int) -> Dict:
        """购买单位"""
        return {"type": ActionType.BUY_UNIT.value, "shop_index": shop_index}

    @staticmethod
    def sell_unit(zone: str, pos) -> Dict:
        """出售单位"""
        return {"type": ActionType.SELL_UNIT.value, "zone": zone, "pos": pos}

    @staticmethod
    def move_unit(from_zone: str, from_pos, to_zone: str, to_pos) -> Dict:
        """移动单位"""
        return {
            "type": ActionType.MOVE_UNIT.value,
            "from_zone": from_zone,
            "from_pos": from_pos,
            "to_zone": to_zone,
            "to_pos": to_pos
        }

    @staticmethod
    def refresh_shop() -> Dict:
        """刷新商店"""
        return {"type": ActionType.REFRESH_SHOP.value}

    @staticmethod
    def lock_shop_slot(shop_index: int) -> Dict:
        """锁定商店槽位"""
        return {"type": ActionType.LOCK_SHOP_SLOT.value, "shop_index": shop_index}

    @staticmethod
    def unlock_shop_slot(shop_index: int) -> Dict:
        """解锁商店槽位"""
        return {"type": ActionType.UNLOCK_SHOP_SLOT.value, "shop_index": shop_index}

    @staticmethod
    def start_wave() -> Dict:
        """开始波次"""
        return {"type": ActionType.START_WAVE.value}

    @staticmethod
    def retry_wave() -> Dict:
        """重试波次"""
        return {"type": ActionType.RETRY_WAVE.value}

    @staticmethod
    def resume(wait_time: Optional[float] = None) -> Dict:
        """恢复游戏"""
        action = {"type": ActionType.RESUME.value}
        if wait_time is not None:
            action["wait_time"] = wait_time
        return action

    # 作弊指令
    @staticmethod
    def cheat_add_gold(amount: int) -> Dict:
        """添加金币（作弊）"""
        return {"type": ActionType.CHEAT_ADD_GOLD.value, "amount": amount}

    @staticmethod
    def cheat_add_mana(amount: float) -> Dict:
        """添加法力（作弊）"""
        return {"type": ActionType.CHEAT_ADD_MANA.value, "amount": amount}

    @staticmethod
    def cheat_spawn_unit(unit_type: str, level: int, zone: str, pos) -> Dict:
        """生成单位（作弊）"""
        return {
            "type": ActionType.CHEAT_SPAWN_UNIT.value,
            "unit_type": unit_type,
            "level": level,
            "zone": zone,
            "pos": pos
        }

    @staticmethod
    def cheat_set_time_scale(scale: float) -> Dict:
        """设置时间倍速（作弊）"""
        return {"type": ActionType.CHEAT_SET_TIME_SCALE.value, "scale": scale}


class AIGameClient:
    """
    AI 游戏客户端

    使用示例:
        client = AIGameClient("ws://localhost:9090")
        await client.connect()

        state = await client.receive_state()
        actions = [
            ActionBuilder.buy_unit(0),
            ActionBuilder.start_wave()
        ]
        await client.send_actions(actions)
    """

    def __init__(self, uri: str = "ws://localhost:9090"):
        self.uri = uri
        self.websocket: Optional[websockets.WebSocketClientProtocol] = None
        self.current_state: Optional[GameState] = None
        self.connected = False

    async def connect(self) -> bool:
        """连接到游戏服务端"""
        try:
            self.websocket = await websockets.connect(self.uri)
            self.connected = True
            logger.info(f"[连接成功] {self.uri}")
            return True
        except Exception as e:
            logger.error(f"[连接失败] {e}")
            return False

    async def disconnect(self):
        """断开连接"""
        if self.websocket:
            await self.websocket.close()
            self.connected = False
            logger.info("[断开连接]")

    async def receive_state(self, timeout: Optional[float] = None) -> Optional[GameState]:
        """
        接收游戏状态

        Args:
            timeout: 超时时间（秒），None 表示不超时

        Returns:
            GameState 对象，超时或错误返回 None
        """
        if not self.websocket:
            return None

        try:
            if timeout:
                message = await asyncio.wait_for(
                    self.websocket.recv(),
                    timeout=timeout
                )
            else:
                message = await self.websocket.recv()

            data = json.loads(message)
            self.current_state = GameState.from_dict(data)

            event = self.current_state.event
            logger.info(f"[收到状态] 事件: {event}")

            # 检查是否是错误
            if event == "ActionError":
                error_msg = data.get("error_message", "Unknown error")
                failed_action = data.get("failed_action", {})
                logger.error(f"[动作错误] {error_msg}, 动作: {failed_action}")

            return self.current_state

        except asyncio.TimeoutError:
            logger.warning("[接收超时]")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"[JSON解析错误] {e}")
            return None
        except Exception as e:
            logger.error(f"[接收错误] {e}")
            return None

    async def send_actions(self, actions: List[Dict]) -> bool:
        """
        发送动作数组

        Args:
            actions: 动作列表

        Returns:
            发送成功返回 True
        """
        if not self.websocket:
            return False

        try:
            message = {"actions": actions}
            json_str = json.dumps(message)
            await self.websocket.send(json_str)
            logger.info(f"[发送动作] {len(actions)} 个动作")
            return True
        except Exception as e:
            logger.error(f"[发送失败] {e}")
            return False

    # ========== 便捷查询方法 ==========

    def get_shop_units(self) -> List[ShopSlot]:
        """获取商店单位列表"""
        if not self.current_state:
            return []
        return self.current_state.shop

    def get_bench_units(self) -> List[BenchSlot]:
        """获取备战区单位（只返回有单位的槽位）"""
        if not self.current_state:
            return []
        return [s for s in self.current_state.bench if s.unit is not None]

    def get_grid_units(self) -> List[GridUnit]:
        """获取网格上的单位"""
        if not self.current_state:
            return []
        return self.current_state.grid

    def get_enemies(self) -> List[Enemy]:
        """获取敌人列表"""
        if not self.current_state:
            return []
        return self.current_state.enemies

    def get_gold(self) -> int:
        """获取当前金币"""
        if not self.current_state:
            return 0
        return self.current_state.gold

    def get_mana(self) -> float:
        """获取当前法力"""
        if not self.current_state:
            return 0
        return self.current_state.mana

    def get_wave(self) -> int:
        """获取当前波次"""
        if not self.current_state:
            return 1
        return self.current_state.wave

    def is_wave_active(self) -> bool:
        """是否处于战斗阶段"""
        if not self.current_state:
            return False
        return self.current_state.is_wave_active

    def find_empty_bench_slot(self) -> int:
        """找到空的备战区槽位，返回索引，没有返回 -1"""
        if not self.current_state:
            return -1
        for slot in self.current_state.bench:
            if slot.unit is None:
                return slot.index
        return -1

    def find_shop_unit(self, unit_key: str) -> Optional[int]:
        """
        在商店中查找指定类型的单位

        Returns:
            商店索引，找不到返回 None
        """
        if not self.current_state:
            return None
        for slot in self.current_state.shop:
            if slot.unit_key == unit_key:
                return slot.index
        return None


class SimpleAI:
    """
    简单 AI 策略示例

    你可以继承这个类或创建自己的 AI 类
    """

    def __init__(self, client: AIGameClient):
        self.client = client
        self.action_history: List[Dict] = []

    async def make_decision(self, state: GameState) -> List[Dict]:
        """
        根据游戏状态做出决策

        Args:
            state: 当前游戏状态

        Returns:
            动作列表
        """
        event = state.event
        actions = []

        if event == EventType.WAVE_ENDED.value:
            actions = await self._handle_shop_phase()

        elif event == EventType.WAVE_STARTED.value:
            # 波次开始，观察战斗
            actions = [ActionBuilder.resume(wait_time=1.0)]

        elif event == EventType.BOSS_SPAWNED.value:
            # Boss 出现，快速观察
            actions = [ActionBuilder.resume(wait_time=0.3)]

        elif event == EventType.CORE_CRITICAL.value:
            # 核心危急，紧急处理
            logger.warning("[AI] 核心血量危急！")
            actions = [ActionBuilder.resume(wait_time=0.5)]

        elif event == EventType.AI_WAKEUP.value:
            # 唤醒，继续观察或采取行动
            if state.is_wave_active:
                actions = [ActionBuilder.resume(wait_time=0.5)]
            else:
                actions = await self._handle_shop_phase()

        elif event == EventType.GAME_OVER.value:
            logger.info("[AI] 游戏结束")
            actions = []

        else:
            # 默认继续
            actions = [ActionBuilder.resume()]

        self.action_history.extend(actions)
        return actions

    async def _handle_shop_phase(self) -> List[Dict]:
        """处理购买阶段"""
        actions = []

        gold = self.client.get_gold()
        logger.info(f"[AI] 处理购买阶段，金币: {gold}")

        # 策略：购买便宜的单位填充备战区
        shop = self.client.get_shop_units()
        empty_bench = self.client.find_empty_bench_slot()

        for slot in shop:
            if empty_bench == -1:
                break
            if slot.unit_key and not slot.locked:
                # 简化策略：购买所有单位
                # 实际应该查询单位价格
                if gold >= 10:
                    actions.append(ActionBuilder.buy_unit(slot.index))
                    gold -= 10
                    empty_bench = self.client.find_empty_bench_slot()

        # 将单位移动到网格
        bench = self.client.get_bench_units()
        grid_positions = [
            {"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0},
            {"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1},
        ]
        grid_idx = 0

        for unit in bench:
            if grid_idx >= len(grid_positions):
                break
            actions.append(ActionBuilder.move_unit(
                "bench", unit.index,
                "grid", grid_positions[grid_idx]
            ))
            grid_idx += 1

        # 开始下一波
        actions.append(ActionBuilder.start_wave())

        return actions


async def run_ai_game(
    uri: str = "ws://localhost:9090",
    ai_class = SimpleAI,
    max_turns: int = 1000
):
    """
    运行 AI 游戏主循环

    Args:
        uri: WebSocket 地址
        ai_class: AI 类（需要接收 AIGameClient 作为参数）
        max_turns: 最大回合数
    """
    client = AIGameClient(uri)

    try:
        # 连接
        if not await client.connect():
            logger.error("无法连接到游戏服务端")
            return

        # 创建 AI
        ai = ai_class(client)

        # 主循环
        turn = 0
        while turn < max_turns:
            turn += 1
            logger.info(f"\n========== 回合 {turn} ==========")

            # 接收状态
            state = await client.receive_state(timeout=30)
            if state is None:
                logger.error("接收状态失败，退出")
                break

            # 检查游戏结束
            if state.event == EventType.GAME_OVER.value:
                logger.info("游戏结束！")
                break

            # AI 决策
            actions = await ai.make_decision(state)

            # 发送动作
            if actions:
                success = await client.send_actions(actions)
                if not success:
                    logger.error("发送动作失败")
                    break

            # 小延迟防止 CPU 占用过高
            await asyncio.sleep(0.01)

        logger.info(f"游戏结束，共进行 {turn} 回合")

    except KeyboardInterrupt:
        logger.info("用户中断")
    except Exception as e:
        logger.error(f"运行时错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await client.disconnect()


# ========== 示例用法 ==========

class MyCustomAI(SimpleAI):
    """自定义 AI 示例"""

    async def make_decision(self, state: GameState) -> List[Dict]:
        """自定义决策逻辑"""
        # 这里写你自己的 AI 逻辑
        # 例如：优先购买特定单位、根据敌人类型调整阵容等

        actions = []

        if state.event == EventType.WAVE_ENDED.value:
            gold = self.client.get_gold()

            # 示例：只购买 wolf
            wolf_idx = self.client.find_shop_unit("wolf")
            if wolf_idx is not None and gold >= 10:
                actions.append(ActionBuilder.buy_unit(wolf_idx))

            # 开始下一波
            actions.append(ActionBuilder.start_wave())

        elif state.is_wave_active:
            # 战斗中，定期观察
            actions = [ActionBuilder.resume(wait_time=1.0)]

        else:
            actions = [ActionBuilder.resume()]

        return actions


if __name__ == "__main__":
    # 运行简单 AI
    print("=" * 60)
    print("Godot AI 游戏客户端")
    print("=" * 60)
    print("请确保 Godot 游戏已启动并运行在 ws://localhost:9090")
    print("按 Ctrl+C 停止")
    print("=" * 60)

    # 使用 SimpleAI 或 MyCustomAI
    asyncio.run(run_ai_game(ai_class=SimpleAI))
