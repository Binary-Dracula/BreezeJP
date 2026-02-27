# 如何手动获取 NHK hdnts Token

运行数据管道需要一个 `hdnts` Token 来下载 NHK Easy News 的音频文件。这个 Token 有效期约 **30 分钟**，需要在运行管道前获取。

## 获取步骤

### 1. 打开 NHK Easy News 网站

在浏览器中访问：
```
https://www3.nhk.or.jp/news/easy/
```

如果是首次访问，会出现 NHK ONE 注册页面，勾选同意并点击「サービスの利用を開始する」。

### 2. 打开浏览器开发者工具

- **Chrome / Edge**：按 `F12` 或 `Cmd+Option+I`
- 切换到 **Network（网络）** 标签页

### 3. 播放任意文章的音频

1. 点击进入任意一篇新闻文章
2. 找到页面上的 **「ニュースを聞く」**（听新闻）按钮
3. 点击播放音频

### 4. 在 Network 面板中找到 Token

播放音频后，Network 面板会出现新的请求。找到以下**任一**请求：

**方法 A：找 m3u8 请求**
- 在 Network 面板的搜索框中输入 `m3u8`
- 找到 `index.m3u8?hdnts=...` 的请求
- 点击该请求，查看完整 URL
- 复制 `hdnts=` 后面的完整字符串

**方法 B：找 mediatoken 请求**
- 在 Network 面板的搜索框中输入 `mediatoken`
- 找到 `https://mediatoken.web.nhk/v1/token` 的请求
- 点击该请求 → Preview/Response 标签
- 复制 `token` 字段的值

### 5. Token 格式

正确的 Token 格式如下：
```
exp=1772209988~acl=/*~hmac=d4565861ec4d25e366cbe666fbe2f64bde8c96a4de3dc0de9d3c5673cfaaa656
```

- `exp=` 后面是过期时间戳（Unix 时间）
- `acl=` 是访问控制列表
- `hmac=` 是签名

### 6. 使用 Token 运行管道

```bash
cd tools/nhk_data_pipeline
bash scripts/run_pipeline.sh --hdnts "exp=...~acl=/*~hmac=..."
```

## DNS 前置条件

> ⚠️ 如果你在中国大陆，NHK 的 CDN 域名可能无法直接解析。首次使用前需要将以下内容添加到 `/etc/hosts`：
>
> ```bash
> echo "23.200.3.236 media.vd.st.nhk" | sudo tee -a /etc/hosts
> echo "184.26.43.72 mediatoken.web.nhk" | sudo tee -a /etc/hosts
> ```
>
> 如果 IP 失效，可以在 [dnschecker.org](https://dnschecker.org) 查询这两个域名的最新 A 记录。

## 常见问题

**Q: Token 显示 403 Forbidden？**
A: Token 已过期（有效期约30分钟）。重新按上述步骤获取新的 Token。

**Q: 音频下载时出现大量 AAC 解码错误？**
A: 这是 Akamai CDN 加密流的正常现象，不影响最终 mp3 文件质量。只要最后显示 `✅ 音频转换完成 (mp3)` 就是成功的。
