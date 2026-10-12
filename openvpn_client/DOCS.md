# 配置说明

## 配置文件存放路径

应用读取 `/share` 共享目录中的文件。推荐目录：

```text
/share/openvpn-client/
├── client.ovpn       # VPN 服务端导出的客户端配置
├── auth.txt          # 如需要：第一行账号，第二行密码
├── ca.crt            # 仅外部证书方式需要
├── client.crt
└── client.key
```

通过 Samba 访问：`\\HOME_ASSISTANT_IP\share\openvpn-client\client.ovpn`。
这里是 **share 共享**，不是 `config` 共享。在 SSH 终端中可直接访问 `/share/openvpn-client/client.ovpn`。HA OS 宿主机底层路径通常为 `/mnt/data/supervisor/share/openvpn-client/client.ovpn`，日常编辑使用 `/share` 即可。

将服务端导出的真实文件放入此目录。不要将示例占位符直接当作可连接配置。外部证书和账号文件可以使用相对路径，如 `ca ca.crt`、`auth-user-pass auth.txt`；应用将以 `.ovpn` 所在目录作为工作目录。

## 应用选项

```yaml
ovpnfile: openvpn-client/client.ovpn
protect_lan: true
lan_interface: ""
lan_gateway: ""
lan_subnet: ""
routing_table: 17800
routing_priority: 17800
```

| 选项 | 说明 |
| --- | --- |
| `ovpnfile` | `/share` 下的相对路径；完整文件路径是 `/share/` 加此选项 |
| `protect_lan` | 启用局域网 IPv4 回程保护，默认开启 |
| `lan_interface` | 留空自动识别本地网卡；多网卡时手动指定 |
| `lan_gateway` | 留空使用本地网卡的默认网关 |
| `lan_subnet` | 留空使用本地 IPv4 地址对应的直连网段 |
| `routing_table` | 本应用独占的路由表编号，1000–32000；已占用时拒绝启动 |
| `routing_priority` | 本应用独占的规则优先级，1000–32000；已占用时拒绝启动 |

保存选项后启动应用。日志会显示实际配置路径和识别出的局域网参数。需要更改文件内容后重启应用才会生效。

## 回程保护如何工作

连接前识别本地 IPv4 地址，并添加源地址策略路由：以本地地址为源的流量通过本地网关返回。VPN 隧道地址保持原有路由。应用同时忽略服务端推送的、目标网络地址与本地网段相同的 `route` 指令，不关闭其他 VPN 路由或全局 VPN 设置。

应用正常停止或收到终止信号后会清理自身规则。强制终止可能留下规则：应先确认规则确实属于本应用，再清理对应路由表与规则，或重启主机。不要同时运行两个使用同一路由表或优先级的实例。

此模式适用于局域网请求需要从本地网关返回的场景。若需要本地源地址流量也通过 VPN，请关闭保护并在 VPN 服务端处理回程。当前只保护一个网卡上的首个全局 IPv4 地址，不处理 IPv6。

## 从临时修复迁移

如果旧 `.ovpn` 文件含有手工添加的 `route-up` 回程修复命令，请先备份文件，删除该旧修复命令，交由本应用管理。旧规则与应用默认的 17800 表互不共用，但遗留优先级更高的规则仍可能影响访问。

从 1.0.1 开始，应用会识别本次旧临时修复中同时包含 `ip route replace table 177` 与 `ip rule add priority 17700` 的 `route-up` 行，在权限为 600 的临时运行配置中忽略它，避免超长命令阻止启动。原始 `.ovpn` 不会被修改，其他用户自定义钩子保持原样。临时运行配置在应用正常退出时删除。

## 常见问题

- **Maximum option line length (256) exceeded，指向旧 route-up**：更新到 1.0.1；或先备份 `/share/openvpn-client/client.ovpn`，仅删除旧临时回程修复的 `route-up` 行。回程保护由应用选项控制，不需要把长命令写入 `.ovpn`。

- **一直等待文件**：检查日志中的完整路径；默认文件必须在 `/share/openvpn-client/client.ovpn`。
- **认证失败**：检查服务端导出的客户端证书和账号文件；证书、私钥、密码应只保存在本地。
- **无法自动识别局域网参数**：手工填写网卡、网关和 CIDR 网段。
- **路由表或优先级已占用**：更换对应编号，避免覆盖其他程序的规则。
- **VPN 地址可访问，局域网地址超时**：确认保护开启且网关正确，再分别测试两个地址；服务端防火墙或路由错误仍需在服务端修复。
