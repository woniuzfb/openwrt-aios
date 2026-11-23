# openwrt-aios

`luci-app-aios` 配套的 OpenWrt 独立命名空间三包发行仓库（支持 OpenWrt 21.02–24.10 `.ipk` 与 OpenWrt 25.12+ `.apk`）。

## 包结构

| 包名 | 架构 | 安装路径 | 说明 |
| :--- | :--- | :--- | :--- |
| `aios-xray` | 各目标架构 | `/usr/bin/aios-xray` | Xray-core 静态二进制（`CGO_ENABLED=0 -trimpath -buildvcs=false -ldflags "-s -w -buildid="`，无 UPX，依赖 `+ca-bundle`） |
| `aios-v2ray` | 各目标架构 | `/usr/bin/aios-v2ray` | V2Ray (v2fly) 静态二进制（`CGO_ENABLED=0 -trimpath -buildvcs=false -ldflags "-s -w -buildid="`，无 UPX，依赖 `+ca-bundle`） |
| `aios-geodata` | `all` | `/usr/share/aios/geodata/{geoip.dat,geosite.dat}` | 来自 [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) 的双核共享 GeoIP / GeoSite 数据文件，全架构通用 |

## 设计原则

- **全维度命名空间隔离**：绝不占用 `/usr/bin/xray`、`/usr/bin/v2ray`、`/usr/share/xray` 或 `/usr/share/v2ray`，可与 OpenWrt 官方 feed 及其他代理插件安全共存。
- **GeoData 独立成包**：`aios-xray` 与 `aios-v2ray` 均不内置 `.dat` 资产文件；`aios-geodata` 仅构建 1 份 `PKGARCH:=all`，小闪存路由器可按需选择不安装或指向外置存储。
- **禁止默认 UPX**：避免小内存路由器运行时解压翻倍占用 RAM 导致 OOM。

## 安装预编译包

从 GitHub Releases 下载对应架构与包格式的产物，并先使用 `sha256sums.txt` 校验完整性：

```bash
# OpenWrt 21.02–24.10（opkg / .ipk）
opkg update
opkg install ./aios-geodata_*_all.ipk ./aios-xray_*_<arch>.ipk

# OpenWrt 25.12+（apk / .apk，第三方未签名本地包需添加 --allow-untrusted）
apk add --allow-untrusted ./aios-geodata-*-all.apk ./aios-xray-*-<arch>.apk
```

## 更新上游版本与校验和

```bash
# 一键拉取最新 Xray / V2Ray / GeoData Release 并写入精确 SHA256
./scripts/update.sh all

# 单独更新指定版本（省略版本号时自动探测最新上游版本，且自动跳过低于当前版本的旧分支补丁）
./scripts/update.sh xray 26.11.9
./scripts/update.sh v2ray 5.56.0
./scripts/update.sh geodata
```

- **V2Ray Pre-release 追踪**：由于 `v2fly/v2ray-core` 较新版本常以 Pre-release 形式发布，`scripts/update.sh` 在自动探测 V2Ray 时会查询 GitHub Releases API 并选取最新的非草稿版本（包含 Pre-release）。
- **`GITHUB_TOKEN` 说明**：本地高频运行 `./scripts/update.sh` 时，建议通过环境变量传入 `GITHUB_TOKEN`（例如 `GITHUB_TOKEN=ghp_xxx ./scripts/update.sh all`），以避免 GitHub REST API 匿名限流。

## 发布新版本

`scripts/release.sh` 会自动执行脚本语法、Workflow YAML 与各包 Makefile 校验和及架构门禁检查，创建带注释的 `v*` tag，并可选择同步上游与推送触发 GitHub Actions 全矩阵打包：

```bash
# 使用当天日期 tag（默认 vYYYY.MM.DD）本地打 tag（不推送）
./scripts/release.sh

# 指定 tag 并在打 tag 前先更新全部上游版本，再推送触发 CI 打包发布
./scripts/release.sh vYYYY.MM.DD --update all --push

# 也可省略 --update 的 target（默认 all），直接跟 tag 与 --push
./scripts/release.sh --update vYYYY.MM.DD --push
```

## 本地 / Feed 集成

将本仓库加入 OpenWrt `feeds.conf` 或克隆至 `package/openwrt-aios`：

```bash
./scripts/feeds update aios
./scripts/feeds install -a -p aios
make menuconfig  # Network -> Web Servers/Proxies -> aios-xray / aios-v2ray / aios-geodata
```
