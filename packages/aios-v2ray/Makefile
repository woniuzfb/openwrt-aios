include $(TOPDIR)/rules.mk

PKG_NAME:=aios-v2ray
PKG_VERSION:=5.56.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=AIOS Contributors

PKG_SOURCE:=v2ray-core-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/v2fly/v2ray-core/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=ab0f2c416d90e6449a49e4ae0da015778a11fc3884dc782e17553234be928475

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/v2fly/v2ray-core/v5

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/../feeds/packages/lang/golang/golang-package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=V2Ray (v2fly) binary for AIOS (independent namespace)
  URL:=https://github.com/v2fly/v2ray-core
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/$(PKG_NAME)/description
  V2Ray (v2fly/v2ray-core) static binary (CGO_ENABLED=0, no UPX) installed to
  /usr/bin/aios-v2ray for luci-app-aios. Uses an independent namespace
  so it never conflicts with official v2ray-core packages.
  GeoData files are provided separately by aios-geodata.
endef

define Package/$(PKG_NAME)/config
menu "AIOS V2Ray Configuration"
	depends on PACKAGE_$(PKG_NAME)

config PACKAGE_AIOS_V2RAY_ENABLE_GOPROXY
	bool "Use goproxy.io to speed up Go module fetching"
	default n

endmenu
endef

USE_GOPROXY:=
ifdef CONFIG_PACKAGE_AIOS_V2RAY_ENABLE_GOPROXY
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
		-o $(PKG_INSTALL_DIR)/bin/aios-v2ray ./main
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/aios-v2ray $(1)/usr/bin/aios-v2ray
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
