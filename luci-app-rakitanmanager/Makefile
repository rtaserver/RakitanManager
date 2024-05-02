# See /LICENSE for more information.
# This is free software, licensed under the GNU General Public License v3.
# Copyright (C) 2024 rtaserver

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Auto Reconnect Modem Rakitan
PKG_NAME:=luci-app-rakitanmanager
LUCI_DEPENDS:=+modemmanager +python3-pip +jq +adb
PKG_VERSION:=0.0.1
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Rizki Kotet <rizkidhc31@gmail.com>

define Package/$(PKG_NAME)
  $(call Package/luci/webtemplate)
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
endef

define Package/$(PKG_NAME)/description
  LuCI version of Rakitiw, with some mods and additions for modem rakitan.
endef

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_modemmanager
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_python3-pip
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_jq
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_adb
	default y if PACKAGE_$(PKG_NAME)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/root/www $(PKG_BUILD_DIR)
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/rakitanmanager
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/rakitanmanager.sh
  	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/modem-orbit.py
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/setuprakitanmanager.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_rakitanmanager
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
	if [ -f "/www/rakitanmanager/data_modem.json" ]; then
		rm -rf /www/rakitanmanager/ >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
	chmod 0755 /usr/bin/rakitanmanager.sh
	chmod 0755 /usr/bin/setuprakitanmanager.sh
    chmod 0755 /usr/bin/modem-orbit.py
	chmod 0755 /etc/init.d/rakitanmanager
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	/usr/bin/rakitanmanager -k
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	rm -rf /etc/rakitanmanager/ >/dev/null 2>&1
	rm -rf /www/rakitanmanager/ >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/www/rakitanmanager
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
	$(CP) $(PKG_BUILD_DIR)/root/www/* $(1)/www/
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))