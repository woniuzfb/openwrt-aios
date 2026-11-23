include $(TOPDIR)/rules.mk

PKG_NAME:=aios-xray
PKG_VERSION:=26.11.9
PKG_RELEASE:=1

PKG_LICENSE:=MPL-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=AIOS Contributors

PKG_SOURCE:=Xray-core-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/XTLS/Xray-core/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=d5a47bed1b85e1cdfe3cb2f88a02e2db7144f0f8bee541d20b84fafa8fdf6c8d

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/xtls/xray-core

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/../feeds/packages/lang/golang/golang-package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Xray-core binary for AIOS (independent namespace)
  URL:=https://github.com/XTLS/Xray-core
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/$(PKG_NAME)/description
  Xray-core static binary (CGO_ENABLED=0, no UPX) installed to
  /usr/bin/aios-xray for luci-app-aios. Uses an independent namespace
  so it never conflicts with official xray-core packages.
  GeoData files are provided separately by aios-geodata.
endef

define Package/$(PKG_NAME)/config
menu "AIOS Xray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_AIOS_XRAY_ENABLE_GOPROXY
	bool "Use goproxy.io to speed up Go module fetching"
	default n

endmenu
endef

USE_GOPROXY:=
ifdef CONFIG_PACKAGE_AIOS_XRAY_ENABLE_GOPROXY
	USE_GOPROXY:=GOPROXY=https://goproxy.io,direct
endif

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(HOST_TAR) -C $(PKG_BUILD_DIR) --strip-components=1 -xzf $(DL_DIR)/$(PKG_SOURCE)
	$(Build/Patch)
endef

define Build/Compile
	mkdir -p $(PKG_INSTALL_DIR)/bin
	cd $(PKG_BUILD_DIR) && \
		$(GO_PKG_VARS) $(USE_GOPROXY) CGO_ENABLED=0 \
		go build -trimpath -buildvcs=false -ldflags "-s -w -buildid=" \
		-o $(PKG_INSTALL_DIR)/bin/aios-xray ./main
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/aios-xray $(1)/usr/bin/aios-xray
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
