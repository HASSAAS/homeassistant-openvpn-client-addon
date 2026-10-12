# OpenVPN Client（修复版）

Home Assistant OS / Supervised 的 OpenVPN 客户端应用，保护本地 IPv4 地址的回程路径，解决 VPN 地址可访问而原局域网地址连接超时的问题。

## 安装

在 **设置 → 应用 → 应用商店 → 右上角菜单 → 仓库** 中添加：

```text
https://github.com/HASSAAS/homeassistant-openvpn-client-addon
```

安装 **OpenVPN Client（修复版）**，按 [配置说明](openvpn_client/DOCS.md) 放置文件，保存应用选项后启动。应用由 Home Assistant 本机构建，支持 amd64、aarch64。

## 配置文件存放路径

完整路径：`/share/openvpn-client/client.ovpn`。

应用选项：`ovpnfile: openvpn-client/client.ovpn`。

Samba 路径：`\\HOME_ASSISTANT_IP\share\openvpn-client\client.ovpn`。这是 **share** 共享，不是 config 共享。

证书、私钥和账号文件保存在同一目录。发布包只有占位示例，不含真实 VPN 配置或密码。

## 路由修复

应用连接前识别局域网网卡、网关和网段，为本地 IPv4 地址创建独立回程路由表，并过滤覆盖本地网段的服务端推送路由。VPN 地址保留原有路由。正常停止时清理自身规则。

可设置 `protect_lan: false` 关闭保护。多网卡建议手工指定局域网参数。IPv6 不在本版本的保护范围内。详细选项和旧配置迁移见 [DOCS.md](openvpn_client/DOCS.md)。

## 来源与文档

本项目针对实际路由问题重新实现启动逻辑，参考 [HedgU4 的应用结构](https://github.com/HedgU4/homeassistant-openvpn-client-addon)，采用用户提供的图标。

配置格式参考 [Home Assistant 官方文档](https://developers.home-assistant.io/docs/apps/configuration/)，路由过滤参考 [OpenVPN 官方手册](https://openvpn.net/community-docs/community-articles/openvpn-2-6-manual.html)。
