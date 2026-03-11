# AI 客户端快速入门（实时非阻塞）

## 1) 启动网关

```bash
python3 ai_client/ai_game_client.py --project . --scene res://src/Scenes/UI/CoreSelection.tscn --http-port 8080
```

## 2) 提交动作（异步）

```bash
curl -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{"request_id":"qs-1","actions":[{"type":"start_wave"}]}'
```

## 3) 拉取事件（可回放）

```bash
curl "http://127.0.0.1:8080/observations?after_seq=0&limit=100&wait_ms=200"
```

## 4) 查看状态

```bash
curl http://127.0.0.1:8080/status
```

## 5) 运行第一波覆盖测试

```bash
python3 ai_client/first_wave_coverage_runner.py --base-url http://127.0.0.1:8080
```
