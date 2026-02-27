# Secrets 目录说明

此目录用于存储敏感信息，如API密钥等。

## 安全注意事项

1. **不要提交到Git仓库**: 此目录下的所有文件(除了README.md和.env.example)都不应该被提交到git
2. **使用 .env 文件**: 复制 `.env.example` 为 `.env` 并填入实际的API密钥
3. **保护API密钥**: 不要将API密钥分享给他人或暴露在公开代码中

## 使用方法

1. 复制 `.env.example` 为 `.env`:
   ```bash
   cp .env.example .env
   ```

2. 编辑 `.env` 文件，填入实际的API密钥:
   ```
   JULES_API_KEY=your_api_key_here
   ```

3. 在调用脚本中读取环境变量:
   ```python
   import os
   from dotenv import load_dotenv

   load_dotenv()
   api_key = os.getenv('JULES_API_KEY')
   ```

## .gitignore 配置

确保项目根目录的 `.gitignore` 包含以下内容:

```
# Secrets
docs/secrets/.env
docs/secrets/*.key
docs/secrets/*.json
!docs/secrets/.env.example
!docs/secrets/README.md
```

## 文件列表

- `.env.example` - 环境变量模板（可提交到git）
- `.env` - 实际环境变量（不可提交到git）
- `README.md` - 此说明文件
