include $(TOPDIR)/rules.mk

PKG_NAME:=we826q-tailscale
PKG_VERSION:=1.104.7
PKG_RELEASE:=1
PKG_LICENSE:=BSD-3-Clause
PKGARCH:=$(ARCH)

include $(INCLUDE_DIR)/package.mk

define Package/we826q-tailscale
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Experimental source-built compressed Tailscale multicall
  DEPENDS:=+xz +kmod-tun +ca-bundle
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./files/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	test -s $(PKG_BUILD_DIR)/tailscale-multicall.xz
	test -s $(PKG_BUILD_DIR)/tailscale.sha256
endef

define Package/we826q-tailscale/install
	$(INSTALL_DIR) $(1)/usr/libexec/we826q-tailscale $(1)/usr/sbin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tailscale-multicall.xz $(1)/usr/libexec/we826q-tailscale/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tailscale.sha256 $(1)/usr/libexec/we826q-tailscale/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wrapper.sh $(1)/usr/libexec/we826q-tailscale/wrapper
	ln -s ../libexec/we826q-tailscale/wrapper $(1)/usr/sbin/tailscale
	ln -s ../libexec/we826q-tailscale/wrapper $(1)/usr/sbin/tailscaled
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tailscale.init $(1)/etc/init.d/we826q-tailscale
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/tailscale.config $(1)/etc/config/we826q-tailscale
endef

# No rc.common postinst enable action: no START/STOP fields and no S symlink.
$(eval $(call BuildPackage,we826q-tailscale))
