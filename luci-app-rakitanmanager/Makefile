include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-rakitanmanager
PKG_VERSION:=0.00.37
PKG_RELEASE:=1
PKG_MAINTAINER:=rtaserver <https://github.com/rtaserver/RakitanManager>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_kmod-inet-diag
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_luci-compat
	default y if PACKAGE_$(PKG_NAME)
endef

define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI support for Modem Manager
	PKGARCH:=all
	DEPENDS:=+bash +curl +unzip
	MAINTAINER:=rtaserver
endef

define Package/$(PKG_NAME)/description
    A LuCI support for Modem Manager
endef

define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/rakitanmanager
	chmod -R 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/
	
	sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/curent.svg 2>/dev/null || true
	sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/versionmain.txt 2>/dev/null || true
	sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/versiondev.txt 2>/dev/null || true

	find $(PKG_BUILD_DIR)/root/etc/init.d/ -type f -exec chmod 0755 {} \;
	find $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/ -type f -name "*.sh" -exec chmod 0755 {} \;
	find $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/ -type f -name "*.py" -exec chmod 0755 {} \;
	find $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/plugins/ -type f -exec chmod 0755 {} \;
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_rakitanmanager 2>/dev/null || true
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
	[ -f "/etc/config/rakitanmanager" ] && cp -f "/etc/config/rakitanmanager" "/tmp/rakitanmanager.bak" 2>/dev/null
	[ -f "/usr/share/rakitanmanager/data-modem.json" ] && cp -f "/usr/share/rakitanmanager/data-modem.json" "/tmp/data-modem.json.bak" 2>/dev/null
	[ -f "/www/rakitanmanager/bot_message.txt" ] && cp -f "/www/rakitanmanager/bot_message.txt" "/tmp/bot_message.txt.bak" 2>/dev/null
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
    sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" /www/rakitanmanager/curent.svg 2>/dev/null || true
    sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" /www/rakitanmanager/versionmain.txt 2>/dev/null || true
    sed -i "s/v0.00.00/v$(PKG_VERSION)-$(PKG_RELEASE)/g" /www/rakitanmanager/versiondev.txt 2>/dev/null || true

    chmod 0755 /usr/share/rakitanmanager/*.sh 2>/dev/null || true
    chmod 0755 /usr/share/rakitanmanager/*.py 2>/dev/null || true
    chmod 0755 /usr/share/rakitanmanager/plugins/*.sh 2>/dev/null || true
    chmod 0755 /etc/init.d/rakitanmanager 2>/dev/null || true

    find /usr/share/rakitanmanager -type f \( -name "*.sh" -o -name "*.py" \) -exec sed -i 's/\r$$//' {} \;
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	PID=$$(pgrep -f /usr/share/rakitanmanager/core-manager.sh)
    [ -n "$$PID" ] && /usr/share/rakitanmanager/core-manager.sh -k 2>/dev/null

    [ -f "/tmp/rakitanmanager.bak" ] && mv -f "/tmp/rakitanmanager.bak" "/etc/config/rakitanmanager" 2>/dev/null
    [ -f "/tmp/data-modem.json.bak" ] && mv -f "/tmp/data-modem.json.bak" "/usr/share/rakitanmanager/data-modem.json" 2>/dev/null
    [ -f "/tmp/bot_message.txt.bak" ] && mv -f "/tmp/bot_message.txt.bak" "/www/rakitanmanager/bot_message.txt" 2>/dev/null

    rm -f /tmp/rakitanmanager.bak /tmp/data-modem.json.bak /tmp/bot_message.txt.bak 2>/dev/null

    uci set rakitanmanager.cfg.enabled='0' 2>/dev/null && uci commit rakitanmanager 2>/dev/null
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	rm -rf /etc/config/rakitanmanager 2>/dev/null
    rm -rf /etc/init.d/rakitanmanager 2>/dev/null
    rm -rf /etc/uci-defaults/99_rakitanmanager 2>/dev/null
    rm -rf /usr/share/rakitanmanager 2>/dev/null
    rm -rf /tmp/log/rakitanmanager.log 2>/dev/null
    rm -rf /www/rakitanmanager 2>/dev/null
	exit 0
endef

define Package/$(PKG_NAME)/install
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
    $(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/share/rakitanmanager
	$(INSTALL_DIR) $(1)/www/rakitanmanager
endef

$(eval $(call BuildPackage,$(PKG_NAME)))