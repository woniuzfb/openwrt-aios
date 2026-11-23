# openwrt-aios

`luci-app-aios` 配套的 OpenWrt 独立命名空间三包发行仓库（支持 OpenWrt 21.02–24.10 `.ipk` 与 OpenWrt 25.12+ `.apk`）。

## 包结构

| 包名 | 架构 | 安装路径 | 说明 |
| :--- | :--- | :--- | :--- |
| `aios-xray` | 各目标架构 | `/usr/bin/aios-xray` | Xray-core 静态二进制（`CGO_ENABLED=0 -trimpath -ldflags "-s -w -buildid="`，无 UPX，依赖 `+ca-certificates`） |
| `aios-v2ray` | 各目标架构 | `/usr/bin/aios-v2ray` | V2Ray (v2fly) 静态二进制（`CGO_ENABLED=0 -trimpath -ldflags "-s -w -buildid="`，无 UPX，依赖 `+ca-certificates`） |
| `aios-geodata` | `all` | `/usr/share/aios/geodata/{geoip.dat,geosite.dat}` | 来自 [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) 的双核共享 GeoIP / GeoSite 数据文件，全架构通用 |

## 设计原则

- **全维度命名空间隔离**：绝不占用 `/usr/bin/xray`、`/usr/bin/v2ray`、`/usr/share/xray` 或 `/usr/share/v2ray`，可与 OpenWrt 官方 feed 及其他代理插件安全共存。
- **GeoData 独立成包**：`aios-xray` 与 `aios-v2ray` 均不内置 `.dat` 资产文件；`aios-geodata` 仅构建 1 份 `PKGARCH:=all`，小闪存路由器可按需选择不安装或指向外置存储。
- **禁止默认 UPX**：避免小内存路由器运行时解压翻倍占用 RAM 导致 OOM。

## 更新上游版本与校验和

```bash
# 一键拉取最新 Xray / V2Ray / GeoData Release 并写入精确 SHA256
./scripts/update.sh all

# 单独更新指定版本
./scripts/update.sh xray 26.11.9
./scripts/update.sh v2ray 5.56.0
./scripts/update.sh geodata
```

## 本地 / Feed 集成

将本仓库加入 OpenWrt `feeds.conf` 或克隆至 `package/openwrt-aios`：

```bash
./scripts/feeds update aios
./scripts/feeds install -a -p aios
make menuconfig  # Network -> Web Servers/Proxies -> aios-xray / aios-v2ray / aios-geodata
```
