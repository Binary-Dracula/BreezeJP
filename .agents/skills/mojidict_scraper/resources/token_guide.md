# MOJiDict 抓取权限 (Token) 获取指南

由于 MOJiDict 的 API 受到权限保护，脚本需要有效的 `_SessionToken` 和 `_InstallationId` 才能抓取完整的合集内容（否则只能看到前 10 个条目）。

如果脚本运行报错（提示身份失效或只能抓取少量数据），请按照以下步骤更新 `main.py` 中的配置：

### 1. 获取方式 (浏览器控制台)

1.  在 PC 浏览器（Chrome/Edge 等）打开 [MOJi辞書官网](https://www.mojidict.com/) 并**确保已登录**。
2.  按下 `F12` 或 `右键 -> 检查` 打开开发者工具。
3.  点击顶级页签中的 **Console (控制台)**。
4.  在底部输入框分别粘贴并回车运行以下代码：

#### 获取 SessionToken:
```javascript
JSON.parse(localStorage.getItem('Parse/E62VyFVLMiW7kvbtVq3p/currentUser'))._sessionToken
```

#### 获取 InstallationId:
```javascript
localStorage.getItem('Parse/E62VyFVLMiW7kvbtVq3p/installationId')
```

### 2. 更新脚本

将获取到的字符串分别复制，并替换 `main.py` 顶部的变量值：

```python
# --- main.py ---
SESSION_TOKEN = "将其替换为您获取到的 Token"
INSTALLATION_ID = "将其替换为您获取到的 InstallationId"
```

### 3. 注意事项
*   **Token 的时效性**: 这个 Token 通常在您清理浏览器缓存或在其他地方登录前是长期有效的。如果在脚本运行中频繁出现 503 错误或空结果，请刷新浏览器后再提取一次。
*   **AppId**: `E62VyFVLMiW7kvbtVq3p` 是 MOJiDict 的固定标识符，通常不需要修改。

---
*整理日期: 2026-04-02*
