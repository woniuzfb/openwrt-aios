include $(TOPDIR)/rules.mk

PKG_NAME:=aios-geodata
# Run ./scripts/update.sh geodata to pin exact release tags and SHA256 hashes
PKG_VERSION:=20261122062944
PKG_RELEASE:=1

PKG_LICENSE:=CC-BY-SA-4.0 MIT
PKG_MAINTAINER:=AIOS Contributors
PKGARCH:=all

GEOIP_VER:=202611080027
GEOIP_FILE:=aios-geoip-$(GEOIP_VER).dat
GEOIP_HASH:=eedb24b3b9fcba27e06b92c0428dab90d9496083091ae4cf39e11387fd99d0e2

GEOSITE_VER:=20261122062944
GEOSITE_FILE:=aios-geosite-$(GEOSITE_VER).dat
GEOSITE_HASH:=29b46dae5d10e8f6bad5ee15bc1ad34107946b552f4e52218681079d56c50854

include $(INCLUDE_DIR)/package.mk

define Download/aios-geoip
  URL:=https://github.com/v2fly/geoip/releases/$(if $(filter latest,$(GEOIP_VER)),latest/download,download/$(GEOIP_VER))
  URL_FILE:=geoip.dat
  FILE:=$(GEOIP_FILE)
  HASH:=$(GEOIP_HASH)
endef

define Download/aios-geosite
  URL:=https://github.com/v2fly/domain-list-community/releases/$(if $(filter latest,$(GEOSITE_VER)),latest/download,download/$(GEOSITE_VER))
  URL_FILE:=dlc.dat
  FILE:=$(GEOSITE_FILE)
  HASH:=$(GEOSITE_HASH)
endef

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Shared GeoIP & GeoSite data files for AIOS
  URL:=https://github.com/v2fly/geoip
endef

define Package/$(PKG_NAME)/description
  Architecture-independent (PKGARCH:=all) geoip.dat and geosite.dat installed to
  /usr/share/aios/geodata/ for sharing between aios-xray and aios-v2ray without
  conflicting with official v2ray-geoip / v2ray-geosite packages.
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
