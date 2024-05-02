include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-rakitanmanager
PKG_VERSION:=0.0.1
PKG_RELEASE:=beta
PKG_MAINTAINER:=rtaserver <https://github.com/rtaserver/RakitanManager>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk


define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI support for Modem Manager
	PKGARCH:=all
	DEPENDS:=+modemmanager +python3-pip +jq +adb +bash +curl +unzip
	MAINTAINER:=rtaserver
endef

define Package/$(PKG_NAME)/description
    A LuCI support for Modem Manager
endef

define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/curent.svg >/dev/null 2>&1
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/rakitiw
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/rakitanmanager.sh
  	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/modem-orbit.py
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/bin/setuprakitiw.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_rakitiw
	exit 0
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
	if [ -f "/www/rakitiw/data_modem.json" ]; then
		rm -rf /www/rakitiw/ >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" /www/rakitanmanager/curent.svg >/dev/null 2>&1
	chmod 0755 /usr/bin/rakitanmanager.sh
	chmod 0755 /usr/bin/setuprakitiw.sh
    chmod 0755 /usr/bin/modem-orbit.py
	chmod 0755 /etc/init.d/rakitiw
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	uci -q set rakitanmanager.config.enable=0
	uci -q commit rakitanmanager
	cp -f "/etc/config/rakitanmanager" "/tmp/rakitanmanager.bak" >/dev/null 2>&1
	cp -rf "/etc/rakitanmanager" "/tmp/rakitanmanager" >/dev/null 2>&1
	cp -rf "/usr/share/rakitanmanager/ui/yacd" "/tmp/rakitanmanager_yacd" >/dev/null 2>&1
	cp -rf "/usr/share/rakitanmanager/ui/dashboard" "/tmp/rakitanmanager_dashboard" >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	rm -rf /etc/rakitiw/ >/dev/null 2>&1
	rm -rf /www/rakitiw/ >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))