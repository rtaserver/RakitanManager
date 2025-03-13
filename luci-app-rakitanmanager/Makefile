include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-rakitanmanager
PKG_VERSION:=0.00.37
PKG_RELEASE:=beta
PKG_MAINTAINER:=rtaserver <https://github.com/rtaserver/RakitanManager>
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+python3-pip +jq +adb +bash +curl +unzip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/description
    A LuCI support for Modem Manager
endef

define Build/Prepare
    $(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
    $(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
    for file in curent.svg versionmain.txt versiondev.txt; do \
        sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" $(PKG_BUILD_DIR)/root/www/rakitanmanager/$$file >/dev/null 2>&1; \
    done
    find $(PKG_BUILD_DIR)/root -type f -name '*.sh' -exec chmod 0755 {} \;
    chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/rakitanmanager
    chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/99_rakitanmanager
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
    [ -f "/etc/config/rakitanmanager" ] && {
        cp -f "/etc/config/rakitanmanager" "/tmp/rakitanmanager.bak" >/dev/null 2>&1
        cp -f "/usr/share/rakitanmanager/data-modem.json" "/tmp/data-modem.json.bak" >/dev/null 2>&1
        cp -f "/www/rakitanmanager/bot_message.txt" "/tmp/bot_message.txt.bak" >/dev/null 2>&1
    }
exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
    for file in curent.svg versionmain.txt versiondev.txt; do \
        sed -i "s/v0.00.00-beta/v$(PKG_VERSION)-beta/g" /www/rakitanmanager/$$file >/dev/null 2>&1; \
    done
    find /usr/share/rakitanmanager -type f -name '*.sh' -exec chmod 0755 {} \;
    chmod 0755 /etc/init.d/rakitanmanager
    echo "Setup php uhttpd"
    uci set uhttpd.main.index_page='index.php'
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
    echo "Setup php uhttpd Done"
    pip3 install --upgrade pip requests huawei-lte-api datetime logging
    find /usr/share/rakitanmanager -type f -exec sed -i 's/\r$$//' {} \;
    echo "Setup ModemManager"
    mm1="/usr/lib/ModemManager/connection.d/10-report-down"
    mm2="/usr/lib/ModemManager/connection.d/10-report-down-and-reconnect"
    mm3="/usr/lib/ModemManager/connection.d/rakitanmanager"

    [ -f "$mm1" ] && rm "$mm1"
    if [ -f "$mm3" ]; then
        [ -f "$mm2" ] && rm "$mm2"
        mv "$mm3" "$mm1"
        chmod +x "$mm1"
    fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
    PID1=$(pgrep -f /usr/share/rakitanmanager/core-manager.sh)
    [ "$PID1" ] && /usr/share/rakitanmanager/core-manager.sh -k
    [ -f "/tmp/rakitanmanager.bak" ] && {
        mv -f "/tmp/rakitanmanager.bak" "/etc/config/rakitanmanager" >/dev/null 2>&1
        mv -f "/tmp/data-modem.json.bak" "/usr/share/rakitanmanager/data-modem.json" >/dev/null 2>&1
        mv -f "/tmp/bot_message.txt .bak" "/www/rakitanmanager/bot_message.txt" >/dev/null 2>&1
        rm -rf "/tmp/rakitanmanager.bak" "/tmp/data-modem.json.bak" "/tmp/bot_message.txt.bak" >/dev/null 2>&1
    }
    uci set rakitanmanager.cfg.enabled='0' && uci commit rakitanmanager
exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
    rm -rf /etc/config/rakitanmanager /etc/init.d/rakitanmanager /etc/uci-defaults/99_rakitanmanager /usr/share/rakitanmanager /tmp/log/rakitanmanager.log /www/rakitanmanager >/dev/null 2>&1
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
