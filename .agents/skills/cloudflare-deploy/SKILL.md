---
name: cloudflare-deploy
description: "部署 Cloudflare Workers API 和 Admin 管理面板到 Cloudflare。Use when: 部署 API, 部署 admin, 发布后端, wrangler deploy, pages deploy, 上线。"
argument-hint: "Deploy workers and/or admin panel"
---

# Cloudflare Deploy

将 BreezeJP 的两个云端服务部署到 Cloudflare：

| 服务           | 技术               | 域名                       | Cloudflare 产品 |
| -------------- | ------------------ | -------------------------- | --------------- |
| API            | TypeScript Workers | `api.binary-dracula.com`   | Workers         |
| Admin 管理面板 | React + Vite       | `breezejp-admin.pages.dev` | Pages           |

## When to Use

- 修改了 `api/workers/` 下的代码后需要发布
- 修改了 `admin/` 下的代码后需要发布
- 用户提到「部署」「上线」「deploy」「发布后端」「发布管理面板」

## Prerequisites

- 已安装 `wrangler`（通过 `npm` 全局或项目内 `npx`）
- 已通过 `wrangler login` 登录 Cloudflare 账号

---

## 1. 部署 Workers API

```bash
cd api/workers
wrangler deploy
```

- 配置文件：`api/workers/wrangler.toml`
- 入口：`api/workers/src/index.ts`
- 部署后可访问：`https://api.binary-dracula.com`

### Workers 环境变量（Secrets）

如需更新 secrets（已在 Cloudflare Dashboard 配置过则无需重复）：

```bash
cd api/workers
echo "值" | wrangler secret put SUPABASE_URL
echo "值" | wrangler secret put SUPABASE_SERVICE_ROLE_KEY
echo "值" | wrangler secret put SUPABASE_JWT_SECRET
```

---

## 2. 部署 Admin 管理面板

```bash
cd admin
npm run build
npx wrangler pages deploy dist --project-name breezejp-admin --branch main --commit-dirty=true
```

> **重要**：必须加 `--branch main`，否则会被当作 preview deployment，自定义域名 `admin.binary-dracula.com` 不会指向它。

- Pages 项目名：`breezejp-admin`
- 生产域名：`https://breezejp-admin.pages.dev/`
- 构建输出目录：`admin/dist/`
- 环境变量文件：`admin/.env`（构建时注入，不上传到 Cloudflare）

### Admin .env 配置

文件路径：`admin/.env`

```
VITE_SUPABASE_URL=https://eecfrzvutrhftwvyebpq.supabase.co
VITE_SUPABASE_ANON_KEY=<anon_key>
```

> `.env` 的值在 `npm run build` 时被 Vite 打包进 JS，部署后不可更改。修改 `.env` 后必须重新 build + deploy。

---

## Procedure

### 仅部署 API

```bash
cd /Users/summer/work/money/breeze_jp/api/workers && wrangler deploy
```

### 仅部署 Admin

```bash
cd /Users/summer/work/money/breeze_jp/admin && npm run build && npx wrangler pages deploy dist --project-name breezejp-admin --branch main --commit-dirty=true
```

### 同时部署两者

按顺序执行上面两组命令。

## Validation

1. **API**: 访问 `https://api.binary-dracula.com/api/v1/health` 或任意已知端点，确认返回正常。
2. **Admin**: 访问 `https://breezejp-admin.pages.dev/`，确认页面加载并能登录。
3. 终端返回码均为 `0`。
