# AGENTS.md — openwrt-aios AI Agent Guidelines

本文档为所有在此代码库上工作的 AI Agent 提供指引与约束规范。在对项目进行任何修改前，请务必完整阅读并严格遵守以下准则。

---

## 1. 项目架构概述

- **独立命名空间三包 Monorepo（`packages/`）**：
  - `packages/aios-xray/Makefile`：Xray-core 纯静态二进制（`CGO_ENABLED=0 -trimpath -ldflags "-s -w -buildid="`），依赖 `+ca-certificates`，安装至 `/usr/bin/aios-xray`。
  - `packages/aios-v2ray/Makefile`：V2Ray (v2fly) 纯静态二进制（同构无 CGO 构建），依赖 `+ca-certificates`，安装至 `/usr/bin/aios-v2ray`。
  - `packages/aios-geodata/Makefile`：`PKGARCH:=all` 独立数据资产包，安装双核共享的 `/usr/share/aios/geodata/{geoip.dat,geosite.dat}`。
- **版本维护与发布脚本（`scripts/`）**：
  - `scripts/update.sh`：自动探测上游 Xray-core / V2Ray / GeoData 最新 Release，并回写精确 `PKG_VERSION` 与 SHA256 `PKG_HASH`（GeoData 统一归一化为 14 位单调递增版本号）。
  - `scripts/release.sh`：执行发布前语法、校验和与 YAML 门禁检查，创建带注释的 `v*` tag，并支持通过 `--push` 推送至 `origin` 触发 GitHub Actions 打包发布。
- **CI/CD（`.github/workflows/`）**：
  - `build-release.yml`：覆盖 OpenWrt `23.05`（`.ipk`，通吃 21.02–24.10）与 `25.12`（`.apk`）双代 SDK 矩阵；`aios-geodata` 独立单任务仅各构 1 份，末尾由单一 `release` job 汇总生成 `sha256sums.txt` 并发布 GitHub Release。
  - `update-packages.yml`：定时或手动触发上游版本与校验和同步。

---

## 2. 核心铁律（强制执行）

### 铁律 1：全维度命名空间隔离
- 严禁占用系统或其他插件路径（`/usr/bin/xray`、`/usr/bin/v2ray`、`/usr/share/xray/`、`/usr/share/v2ray/`）。
- 三个子包固定输出至 `/usr/bin/aios-xray`、`/usr/bin/aios-v2ray` 与 `/usr/share/aios/geodata/`，不得与官方 `xray-core`/`v2ray-core`/`v2ray-geoip`/`v2ray-geosite` 产生文件冲突。

### 铁律 2：构建安全、可复现与小内存友好
- **必须精确校验和**：严禁使用 `HASH:=skip` 或 `PKG_SOURCE_PROTO:=git` 浮动构建；所有源码与 GeoData 下载项必须锁定精确版本与 SHA256。
- **禁止默认 UPX**：UPX 运行时解压会翻倍占用 RAM，在 64/128MB 内存路由器上极易引发 OOM，禁止默认开启 UPX 压缩。
- **GeoData 独立成包**：禁止将 `geoip.dat` / `geosite.dat` 打入 `aios-xray` 或 `aios-v2ray`；`aios-geodata` 必须保持 `PKGARCH:=all` 与 14 位严格单调递增 `PKG_VERSION`。

### 铁律 3：交付前语法与工作流校验（0 语法错误）
- 任何对 `scripts/`、`.github/workflows/` 或 `packages/` 的修改，交付前必须通过：
  ```bash
  bash -n scripts/update.sh scripts/release.sh
  ruby -ryaml -e "Dir.glob('.github/workflows/*.yml').each { |f| YAML.load_file(f) }; puts 'YAML_OK'"
  ```
- 确认所有 Makefile 均含精确 `PKG_VERSION` 与 `PKG_HASH`（无 `HASH:=skip`）。

### 铁律 4：严禁未经允许擅自改变 Git 状态
- 未经用户明确许可，禁止执行 `git add`、`git commit`、`git push`、`git reset` 或修改暂存区。
- 授权 Commit 时，Commit Message 必须清晰详尽地说明改动背景、范围与验证结果。

### 铁律 5：绝对禁止提交 `.memory/` 目录
- `.memory/` 仅用于本地上下文沉淀，已加入 `.gitignore`，严禁强制 `git add -f .memory/` 或提交至版本控制。

### 铁律 6：严禁自行启停系统服务与掩盖错误（Fail Fast）
- 未经用户明确许可，禁止启停宿主机常驻服务。
- 脚本与工作流必须开启 `set -euo pipefail`，遇到校验失败、下载失败或参数非法时立即返回非零退出码，禁止静默吞错。
- 代码注释只描述事实与约束，不引用外部本地文件路径，不写死无关日期。

---

## 3. 标准维护与发布流程

1. 运行 `./scripts/update.sh all`（或指定子包）同步上游最新版本与精确 SHA256。
2. 校验脚本语法（`bash -n`）与工作流 YAML（`YAML.load_file`）。
3. 提交版本变更后，执行 `./scripts/release.sh vYYYY.MM.DD --push`（或本地打 tag 后手动 push）触发 GitHub Actions 全矩阵打包与 Release 发布。
