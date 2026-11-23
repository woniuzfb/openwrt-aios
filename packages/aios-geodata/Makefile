include $(TOPDIR)/rules.mk

PKG_NAME:=aios-geodata
# Run ./scripts/update.sh geodata to pin exact release tag, 14-digit monotonic PKG_VERSION, and SHA256 hashes
PKG_VERSION:=20261122220300
PKG_RELEASE:=1

PKG_LICENSE:=CC-BY-SA-4.0 MIT
PKG_MAINTAINER:=AIOS Contributors
PKGARCH:=all

GEOIP_VER:=202611222203
GEOIP_FILE:=aios-geoip-$(GEOIP_VER).dat
GEOIP_HASH:=d4ec4c5e5d5a38c1399964ea9fd8c94288426a3b31b483904b67819fc07f4466

GEOSITE_VER:=202611222203
GEOSITE_FILE:=aios-geosite-$(GEOSITE_VER).dat
GEOSITE_HASH:=94e6f902cfa9d4d70ebf3c0138d9cc24175b51885c490cb673ee54f5e1b6ce6f

include $(INCLUDE_DIR)/package.mk

define Download/aios-geoip
  URL:=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$(GEOIP_VER)
  URL_FILE:=geoip.dat
  FILE:=$(GEOIP_FILE)
  HASH:=$(GEOIP_HASH)
endef

define Download/aios-geosite
  URL:=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$(GEOSITE_VER)
  URL_FILE:=geosite.dat
  FILE:=$(GEOSITE_FILE)
  HASH:=$(GEOSITE_HASH)
endef

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Shared GeoIP & GeoSite data files for AIOS
  URL:=https://github.com/Loyalsoldier/v2ray-rules-dat
endef

define Package/$(PKG_NAME)/description
  Architecture-independent (PKGARCH:=all) geoip.dat and geosite.dat from
  Loyalsoldier/v2ray-rules-dat installed to /usr/share/aios/geodata/ for sharing
  between aios-xray and aios-v2ray without conflicting with official
  v2ray-geoip / v2ray-geosite packages.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/share/aios/geodata
	$(INSTALL_DATA) $(DL_DIR)/$(GEOIP_FILE) $(1)/usr/share/aios/geodata/geoip.dat
	$(INSTALL_DATA) $(DL_DIR)/$(GEOSITE_FILE) $(1)/usr/share/aios/geodata/geosite.dat
endef

$(eval $(call Download,aios-geoip))
$(eval $(call Download,aios-geosite))
$(eval $(call BuildPackage,$(PKG_NAME)))
