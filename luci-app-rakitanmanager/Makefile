
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-rakitanmanager
PKG_VERSION:=0.00.34
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
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/versionmain.txt >/dev/null 2>&1
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/versiondev.txt >/dev/null 2>&1
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/rakitanmanager
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/core-manager.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/modem-hilink.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/modem-mf90.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/modem-hp.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/modem-rakitan.sh
  	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/modem-orbit.py
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/plugins/adb-deviceinfo.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/plugins/adb-sms.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/plugins/service-openclash.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/share/rakitanmanager/plugins/systeminfo.sh
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_rakitanmanager
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
	if [ -f "/etc/config/rakitanmanager" ]; then
		cp -f "/etc/config/rakitanmanager" "/tmp/rakitanmanager.bak" >/dev/null 2>&1
		cp -f "/usr/share/rakitanmanager/data-modem.json" "/tmp/data-modem.json.bak" >/dev/null 2>&1
		cp -f "/www/rakitanmanager/bot_message.txt" "/tmp/bot_message.txt.bak" >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" /www/rakitanmanager/curent.svg >/dev/null 2>&1
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" /www/rakitanmanager/versionmain.txt >/dev/null 2>&1
	sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" /www/rakitanmanager/versiondev.txt >/dev/null 2>&1
	chmod 0755 /usr/share/rakitanmanager/core-manager.sh
	chmod 0755 /usr/share/rakitanmanager/modem-hilink.sh
	chmod 0755 /usr/share/rakitanmanager/modem-mf90.sh
	chmod 0755 /usr/share/rakitanmanager/modem-hp.sh
	chmod 0755 /usr/share/rakitanmanager/modem-rakitan.sh
    chmod 0755 /usr/share/rakitanmanager/modem-orbit.py
	chmod 0755 /usr/share/rakitanmanager/plugins/adb-deviceinfo.sh
	chmod 0755 /usr/share/rakitanmanager/plugins/adb-sms.sh
	chmod 0755 /usr/share/rakitanmanager/plugins/service-openclash.sh
	chmod 0755 /root/usr/share/rakitanmanager/plugins/systeminfo.sh
	chmod 0755 /etc/init.d/rakitanmanager
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	PID1=$(pgrep -f /usr/share/rakitanmanager/core-manager.sh)
    if [ "$PID1" ]  ; then
        /usr/share/rakitanmanager/core-manager.sh -k
    fi
	cp -f "/etc/config/rakitanmanager" "/tmp/rakitanmanager.bak" >/dev/null 2>&1
	cp -f "/usr/share/rakitanmanager/data-modem.json" "/tmp/data-modem.json.bak" >/dev/null 2>&1
	cp -f "/www/rakitanmanager/bot_message.txt" "/tmp/bot_message.txt.bak" >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	rm -rf /etc/config/rakitanmanager >/dev/null 2>&1
	rm -rf /etc/init.d/rakitanmanager >/dev/null 2>&1
	rm -rf /etc/uci-defaults/99_rakitanmanager >/dev/null 2>&1
	rm -rf /usr/share/rakitanmanager >/dev/null 2>&1
	rm -rf /tmp/log/rakitanmanager.log >/dev/null 2>&1
	rm -rf /www/rakitanmanager >/dev/null 2>&1
	exit 0
endef

define Package/$(PKG_NAME)/install
    $(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/share/rakitanmanager
    $(INSTALL_DIR) $(1)/www/rakitanmanager
    $(CP) $(PKG_BUILD_DIR)/root/* $(1)/
    $(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))