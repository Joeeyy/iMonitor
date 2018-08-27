#  testVPN 

## 进度
1. 2018-08-20  testVPN 框架
    完成testVPN中关于vpn配置的若干操作。
    
2. 2018-08-21 testVPN 测试用APP：MakePost
    完成名为MakePost的测试用APP，主要用于简单化网络请求发送，有利于后续的功能测试工作。
    
3. 2018-08-23 testVPN 服务代码完成
    完成testVPN 中服务性质代码的编写。
    testVPNServices中的`util.swift`、`Tunnel.swift`、`ClientTunnel.swift`、`Connection.swift`
    `util.swift`是公用代码，内涵普遍用到的工具类、工具方法等
    `Tunnel.swfit`是隧道基类，定义了最为基础的隧道
    `ClientTunnel.swift`是对客户端隧道的定义
    `Connection.swift`是对连接的定义
    
4. 2018-08-24 晚 开始着手packetTunnelProvider类的实现。
    实现完成，下一步应该对VPN链接进行测试，完成：
    > 1 搞清楚整个VPN流量流程
    > 2 确定实现过程有没有失误
    > 3 为下一步APP Proxy实现做铺垫
    
5. 2018-08-25 着手VPN链接测试
    > 1 测试过程中发现链接被拒绝，尝试重写tunnel_server程序
    > 2 经检查，问题应该出现在`ClientTunnel.swift`和`util.swift`中。
    > 3 完成了针对`MakePost`的PerAppProxy测试配置，下一步应该是针对数据流流程的分析。包括如何封包解包，如何进行数据处理等等。
    
6. 2018-08-27 数据流分析阶段
    > 1 首先规整整个项目代码，各个功能按钮分工明确，debug输出清晰
    > 2 debug信息输出梳理，调整tag，调整debug输出内容，调整debug信息主要面向数据流处理过程。
    > 3 下一步，记录网络流日志。确定本机ip，确定服务端代码处理过程。如果需要在服务器端进行抓包，如何进行。
    
    
## 测试记录（testVPN）
1. start vpn tunnel:
```
默认    15:18:32.458837 +0800    packetTunnel    <AINASSINE> PacketTunnelProvider:  starting VPN Tunnel.
默认    15:18:32.459513 +0800    packetTunnel    <AINASSINE> ClientTunnel: starting tunnel
默认    15:18:32.467133 +0800    packetTunnel    <AINASSINE> ClientTunnel: observe changes to the tunnel connection state
默认    15:18:32.471326 +0800    packetTunnel    <AINASSINE> Tunnel connection state changed to Connecting
默认    15:18:32.473627 +0800    packetTunnel    <AINASSINE> ClientTunnel: observe changes to the tunnel connection state
默认    15:18:32.473686 +0800    packetTunnel    <AINASSINE> Tunnel connection state changed to Connected
默认    15:18:32.473744 +0800    packetTunnel    <AINASSINE> ClientTunnel: reading next packet
默认    15:18:32.473804 +0800    packetTunnel    <AINASSINE> ClientTunnelConnection: initializing ClientTunnelConnection
默认    15:18:32.473856 +0800    packetTunnel    <AINASSINE> Connection: init connection
默认    15:18:32.473922 +0800    packetTunnel    <AINASSINE> Tunnel: adding connection
默认    15:18:32.474045 +0800    packetTunnel    <AINASSINE> ClientTunnelConnection: open the connection by sending an open connection message
默认    15:18:32.474328 +0800    packetTunnel    <AINASSINE> ClientTunnel: send a message to the tunnel server
默认    15:18:32.474382 +0800    packetTunnel    <AINASSINE> Tunnel: serialize message
默认    15:18:32.522854 +0800    packetTunnel    <AINASSINE> Tunnel: handle packet, process a message payload
默认    15:18:32.523412 +0800    packetTunnel    <AINASSINE> ClientTunnel: handle message received from the tunnel server
默认    15:18:32.523929 +0800    packetTunnel    <AINASSINE> ClientTunnelConnection: handling the event of the connection being established
默认    15:18:32.524176 +0800    packetTunnel    <AINASSINE> PacketTunnelProvider: tunnelConnectionDidOpen, going to set settings for it.
默认    15:18:32.524248 +0800    packetTunnel    <AINASSINE> PacketTunnelProvider: creating tunnel settings from configuration
默认    15:18:32.526302 +0800    packetTunnel    <AINASSINE> ClientTunnel: reading next packet
默认    15:18:37.647045 +0800    packetTunnel    <AINASSINE> ClientTunnelConnection: start handling packets
```
2. stop vpn tunnel:
```
默认    15:19:53.157867 +0800    packetTunnel    <AINASSINE> PacketTunnelProvider: stopping tunnel
默认    15:19:53.158178 +0800    packetTunnel    <AINASSINE> ClientTunnel: closing tunnel
默认    15:19:53.158557 +0800    packetTunnel    <AINASSINE> Tunnel: closing tunnel
默认    15:19:53.159024 +0800    packetTunnel    <AINASSINE> Connection: abort connection
默认    15:19:53.165199 +0800    packetTunnel    <AINASSINE> ClientTunnel: observe changes to the tunnel connection state
默认    15:19:53.169343 +0800    packetTunnel    <AINASSINE> Tunnel connection state changed to Cancelled
```
3. start per app proxy:
```
默认    15:20:43.430819 +0800    appProxy    <AINASSINE> AppProxyProvider:  starting PER_APP_PROXY tunnel
默认    15:20:43.431244 +0800    appProxy    <AINASSINE> ClientTunnel: starting tunnel
默认    15:20:43.434184 +0800    appProxy    <AINASSINE> ClientTunnel: observe changes to the tunnel connection state
默认    15:20:43.436855 +0800    appProxy    <AINASSINE> Tunnel connection state changed to Connecting
默认    15:20:43.437309 +0800    appProxy    <AINASSINE> AppProxyProvider:  PER_APP_PROXY started successfully!
默认    15:20:43.495823 +0800    appProxy    <AINASSINE> ClientTunnel: observe changes to the tunnel connection state
默认    15:20:43.496235 +0800    appProxy    <AINASSINE> Tunnel connection state changed to Connected
默认    15:20:43.496343 +0800    appProxy    <AINASSINE> ClientTunnel: reading next packet
默认    15:20:43.496582 +0800    appProxy    <AINASSINE> AppProxyProvider:  Tunnel opened, fetching configuration
默认    15:20:43.496811 +0800    appProxy    <AINASSINE> ClientTunnel: send fetch configuration
默认    15:20:43.497131 +0800    appProxy    <AINASSINE> Tunnel: send message
默认    15:20:43.497303 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    15:20:43.498060 +0800    appProxy    <AINASSINE> ClientTunnel: write data to tunnel
默认    15:20:43.505251 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload
默认    15:20:43.505747 +0800    appProxy    <AINASSINE> ClientTunnel: handle message received from the tunnel server
默认    15:20:43.506628 +0800    appProxy    <AINASSINE> AppProxyProvider:  Server sent configuration: ["DNS": {
                                                                                                    SearchDomains =     ();
                                                                                                    Servers =     (
                                                                                                    "240e:c0:f008:71a6::7b",
                                                                                                    "192.168.43.1"
                                                                                                    );
                                                                                                    }]
默认    15:20:43.506978 +0800    appProxy    <AINASSINE> AppProxyProvider:  Calling setTunnelNetworkSettings
默认    15:20:43.507855 +0800    appProxy    <AINASSINE> ClientTunnel: reading next packet
```
4. make a post
```
默认    15:22:03.929865 +0800    appProxy    <AINASSINE> AppProxyProvider:  A new PER_APP_PROXY_FLOW comes, start handling it.
默认    15:22:03.930051 +0800    appProxy    <AINASSINE> AppProxyProvider:  it's a TCP Flow, description: TCP cn.edu.nudt.MakePost[<bf312cae 556dc6ce 74208943 da598646 eb7cffc1>] remote: 192.168.43.137:80, from app: cn.edu.nudt.MakePost.
默认    15:22:03.930794 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  initializing a new ClientAppProxyConnection
默认    15:22:03.930873 +0800    appProxy    <AINASSINE> Connection: init connection
默认    15:22:03.930954 +0800    appProxy    <AINASSINE> Tunnel: adding connection
默认    15:22:03.931124 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling sending an open message 
默认    15:22:03.931312 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:03.931490 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:03.933681 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol
默认    15:22:03.933755 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server
默认    15:22:03.933796 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    15:22:03.934411 +0800    appProxy    <AINASSINE> AppProxyProvider:  new connection established.
默认    15:22:03.973691 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload
默认    15:22:03.974081 +0800    appProxy    <AINASSINE> ClientTunnel: handle message received from the tunnel server
默认    15:22:03.974438 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  handling open completed messaged received from the SimpleTunnel server
默认    15:22:03.975690 +0800    appProxy    <AINASSINE> ClientTunnel: reading next packet
默认    15:22:03.975765 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    15:22:03.975886 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:03.981723 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  sending a data message to the server.
默认    15:22:03.983223 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server
默认    15:22:03.983305 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    15:22:03.983628 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    15:22:03.983796 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:03.984009 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  sending a data message to the server.
默认    15:22:03.984103 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server
默认    15:22:03.984183 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    15:22:03.984450 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    15:22:03.984620 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:04.095492 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload
默认    15:22:04.102416 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: send data received from the server to the destination application
默认    15:22:04.103046 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    15:22:04.106870 +0800    appProxy    <AINASSINE> ClientTunnel: reading next packet
默认    15:22:09.191063 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload
默认    15:22:09.192821 +0800    appProxy    <AINASSINE> <AINASSINE> testVPN Tunnel.swift: Optional(600140792): closing writes
默认    15:22:09.193010 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  closing connection
默认    15:22:09.193436 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: closing connection.
默认    15:22:09.193691 +0800    appProxy    <AINASSINE> Connection: close connection
默认    15:22:09.194050 +0800    appProxy    <AINASSINE> Tunnel: droping connection
默认    15:22:09.198316 +0800    appProxy    <AINASSINE> ClientTunnel: reading next packet
```

5. 对于<4>中的解析：
AppProxyProvider最先收到“来了一条perappproxy流”的通知
紧接着识别出流的信息，包括目的地址，来自哪一个app（根据app的bundle id）
建立一个ClientPerAppProxyConnection，并在隧道中添加该ClientPerAppProxyConnection
ClientPerAPPConnection建立时，向服务器发送“Open”消息，企图打开该连接，该消息由ClientTunnel发送，由Tunnel完成序列化，收到服务器的确认消息，连接方才建立完成。
后续就是连接通信的过程。Tunnel是整个过程最底层的。
下面企图打印出连接消息内容。

6. 对应抓包结果`MakePost_SimpleTunneled_2.pcap`
```
默认    21:26:46.858408 +0800    appProxy    <AINASSINE> AppProxyProvider:  A new PER_APP_PROXY_FLOW comes, start handling it.
默认    21:26:46.858612 +0800    appProxy    <AINASSINE> AppProxyProvider:  it's a TCP Flow, description: TCP cn.edu.nudt.MakePost[<bf312cae 556dc6ce 74208943 da598646 eb7cffc1>] remote: 192.168.43.137:80, from app: cn.edu.nudt.MakePost.
默认    21:26:46.858675 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  initializing a new ClientAppProxyConnection
默认    21:26:46.858729 +0800    appProxy    <AINASSINE> Connection: init connection
默认    21:26:46.858847 +0800    appProxy    <AINASSINE> Tunnel: adding connection
默认    21:26:46.858991 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling sending an open message 
默认    21:26:46.859142 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.859230 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.859499 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  send an "Open" message to the SimpleTunnel server, to begin the process of establishing a flow of data in the SimpleTunnel protocol
默认    21:26:46.859707 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server, messageProperties: ["identifier": 844068063, "app-proxy-flow-type": 1, "port": 80, "command": 6, "tunnel-type": 0, "host": 192.168.43.137]
默认    21:26:46.859759 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    21:26:46.859960 +0800    appProxy    <AINASSINE> Tunnel: serialized message content(Optional(161)): Optional(<a1000000 62706c69 73743030 d6010203 04050607 08090a0b 0c5a6964 656e7469 66696572 5f101361 70702d70 726f7879 2d666c6f 772d7479 70655470 6f727457 636f6d6d 616e645b 74756e6e 656c2d74 79706554 686f7374 12324f74 df100110 50100610 005e3139 322e3136 382e3433 2e313337 08152036 3b434f54 595b5d5f 61000000 00000001 01000000 00000000 0d000000 00000000 00000000 00000000 70>)
默认    21:26:46.860120 +0800    appProxy    <AINASSINE> AppProxyProvider:  new connection established.
默认    21:26:46.896935 +0800    appProxy    <AINASSINE> ClientTunnel: read payload data: length: Optional(94), content: <62706c69 73743030 d3010203 04050657 636f6d6d 616e645b 72657375 6c742d63 6f64655a 6964656e 74696669 65721007 10001232 4f74df08 0f17232e 30320000 00000000 01010000 00000000 00070000 00000000 00000000 00000000 0037>
默认    21:26:46.897234 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload.
默认    21:26:46.897427 +0800    appProxy    <AINASSINE> Tunnel: handle packet content: properties: ["command": 7, "result-code": 0, "identifier": 844068063]
默认    21:26:46.897614 +0800    appProxy    <AINASSINE> ClientTunnel: handle message received from the tunnel server, commandType: OpenResult, properties: ["command": 7, "result-code": 0, "identifier": 844068063]
默认    21:26:46.897725 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  handling open completed messaged received from the SimpleTunnel server
默认    21:26:46.898423 +0800    appProxy    <AINASSINE> ClientTunnel:  reading next packet
默认    21:26:46.898586 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    21:26:46.898637 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.900324 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  sending a data message to the server.
默认    21:26:46.900540 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server, messageProperties: ["command": 1, "data": <OS_dispatch_data: data[0x125f0dce0] = { leaf, size = 287, buf = 0x125f06df0 }>, "identifier": 844068063]
默认    21:26:46.900619 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    21:26:46.900817 +0800    appProxy    <AINASSINE> Tunnel: serialized message content(Optional(387)): Optional(<83010000 62706c69 73743030 d3010203 04050657 636f6d6d 616e6454 64617461 5a696465 6e746966 69657210 014f1101 1f504f53 54202f74 6573742f 68747470 5f726571 75657374 2f746573 74706f73 742e7068 70204854 54502f31 2e310d0a 486f7374 3a203139 322e3136 382e3433 2e313337 0d0a436f 6e74656e 742d5479 70653a20 6170706c 69636174 696f6e2f 782d7777 772d666f 726d2d75 726c656e 636f6465 640d0a43 6f6e6e65 6374696f 6e3a206b 6565702d 616c6976 650d0a41 63636570 743a202a 2f2a0d0a 55736572 2d416765 6e743a20 4d616b65 506f7374 2f312043 464e6574 776f726b 2f393032 2e322044 61727769 6e2f3137 2e372e30 0d0a4163 63657074 2d4c616e 67756167 653a207a 682d636e 0d0a436f 6e74656e 742d4c65 6e677468 3a203231 0d0a4163 63657074 2d456e63 6f64696e 673a2067 7a69702c 20646566 6c617465 0d0a0d0a 12324f74 df000800 0f001700 1c002700 29014c00 00000000 00020100 00000000 00000700 00000000 00000000 00000000 000151>)
默认    21:26:46.900934 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    21:26:46.901047 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.901190 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  sending a data message to the server.
默认    21:26:46.901231 +0800    appProxy    <AINASSINE> ClientTunnel: send a message to the tunnel server, messageProperties: ["command": 1, "data": <OS_dispatch_data: data[0x127012b00] = { leaf, size = 21, buf = 0x127016a60 }>, "identifier": 844068063]
默认    21:26:46.901388 +0800    appProxy    <AINASSINE> Tunnel: serialize message
默认    21:26:46.901494 +0800    appProxy    <AINASSINE> Tunnel: serialized message content(Optional(113)): Optional(<71000000 62706c69 73743030 d3010203 04050657 636f6d6d 616e6454 64617461 5a696465 6e746966 69657210 014f1015 7b0a2020 226b6579 22203a20 2276616c 7565220a 7d12324f 74df080f 171c2729 41000000 00000001 01000000 00000000 07000000 00000000 00000000 00000000 46>)
默认    21:26:46.901603 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: handling result of sending a data message
默认    21:26:46.901665 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.914628 +0800    appProxy    <AINASSINE> ClientTunnel: read payload data: length: Optional(350), content: <62706c69 73743030 d3010203 04050657 636f6d6d 616e6454 64617461 5a696465 6e746966 69657210 014f10ff 48545450 2f312e31 20323030 204f4b0d 0a446174 653a204d 6f6e2c20 32372041 75672032 30313820 31333a32 363a3436 20474d54 0d0a5365 72766572 3a204170 61636865 2f322e34 2e333320 28556e69 78292050 48502f37 2e312e31 360d0a58 2d506f77 65726564 2d42793a 20504850 2f372e31 2e31360d 0a436f6e 74656e74 2d4c656e 6774683a 2032340d 0a4b6565 702d416c 6976653a 2074696d 656f7574 3d352c20 6d61783d 3130300d 0a436f6e 6e656374 696f6e3a 204b6565 702d416c 6976650d 0a436f6e 74656e74 2d547970 653a2061 70706c69 63617469 6f6e2f6a 736f6e0d 0a0d0a7b 22636f64 65223a30 2c226572 724d7367 223a224f 4b227d12 324f74df 0008000f 0017001c 00270029 012b0000 00000000 02010000 00000000 00070000 00000000 00000000 00000000 0130>
默认    21:26:46.914781 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload.
默认    21:26:46.915277 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: TCP: send data received from the server to the destination application
默认    21:26:46.915321 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: new TCP FLOW
默认    21:26:46.915829 +0800    appProxy    <AINASSINE> ClientTunnel:  reading next packet
默认    21:26:52.001853 +0800    appProxy    <AINASSINE> ClientTunnel: read payload data: length: Optional(93), content: <62706c69 73743030 d3010203 04050657 636f6d6d 616e645a 636c6f73 652d7479 70655a69 64656e74 69666965 72100410 0312324f 74df080f 17222d2f 31000000 00000001 01000000 00000000 07000000 00000000 00000000 00000000 36>
默认    21:26:52.001934 +0800    appProxy    <AINASSINE> Tunnel: handle packet, process a message payload.
默认    21:26:52.002244 +0800    appProxy    <AINASSINE> Tunnel: handle packet content: properties: ["command": 4, "close-type": 3, "identifier": 844068063]
默认    21:26:52.002436 +0800    appProxy    <AINASSINE> ClientAppProxyConnection:  closing connection
默认    21:26:52.002498 +0800    appProxy    <AINASSINE> ClientAppProxyConnection: closing connection.
默认    21:26:52.002612 +0800    appProxy    <AINASSINE> Connection: close connection
默认    21:26:52.002826 +0800    appProxy    <AINASSINE> Tunnel: droping connection
默认    21:26:52.003800 +0800    appProxy    <AINASSINE> ClientTunnel:  reading next packet
```



## 测试记录（MakePost）
1. 客户端APP：
    > 1. 指定接收POST请求的服务器IP
    > 2. 发送POST请求，wireshark截包：`MakePost_rawRec.pcap`，请求内容：
        ```
        Form item: "{
        "key" : "value"
        }" = ""
        ```
        > 3. 发送POST请求，wireshark截包：`MakePost_SimpleTunneled.pcap`，请求内容：（同上）
2. 服务器端：
    > 1. 服务器脚本：testpost.php
    > 2. 操作内容：记录post时间，post内容。

## 其他配置
1. MakePost服务器配置：
> 1. IP: 192.168.43.137
> 2. 语言：PHP
> 3. 请求API：http://hostAddress/test/http_request/testpost.php

2. 手机（iPhone 8）：
> 1. OS version: iOS 11.4
> 2. IP: 192.168.43.167

3. per-app proxy
> 1. 使用配置文件`testVPN.mobileconfig`，内容如下：
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>PayloadContent</key>
<array>
<dict>  
<key>PayloadUUID</key>
<string>944561DB-AEAD-43FA-8DC0-F8661BF5CC9A</string>  
<key>PayloadType</key>
<string>com.apple.vpn.managed.applayer</string>  
<key>PayloadIdentifier</key>
<string>com.apple.vpn.managed.applayer.7EDB76A2-ADFC-4D2B-8831-0BA2B1C75579</string>  
<key>VPNType</key>
<string>VPN</string>  
<key>VPNSubType</key>
<string>cn.edu.nudt.testVPN</string>
<key>UserDefinedName</key>
<string>testVPNPerAppProxy2</string>  
<key>PayloadDescription</key>
<string>Configures PerAPP Proxy settings for testVPN</string>  
<key>PayloadDisplayName</key>
<string>testVPNPerAppProxy3</string>  
<key>PayloadVersion</key>
<integer>1</integer>  
<key>VPNUUID</key>  
<string>12DDB7F7-C529-497E-AB79-B02870741EC4</string>
<key>VPN</key>
<dict>  
<key>RemoteAddress</key>
<string>192.168.43.137:6668</string>
<key>AuthenticationMethod</key>
<string>Password</string>
<key>AuthName</key>
<string>mrgumby</string>  
<key>AuthPassword</key>
<string>opendoor</string>  
<key>OnDemandMatchAppEnabled</key>
<false/>  
</dict>  
<key>Proxies</key>  
<dict>  
<key>HTTPEnable</key>  
<integer>0</integer>  
<key>HTTPSEnable</key>  
<integer>0</integer>  
</dict>  
<key>SafariDomains</key>  
<array>  
<string>httpbin.org</string>  
</array>  
</dict>  
</array>
<key>PayloadDisplayName</key>
<string>testVPNPerAppProxy</string>
<key>PayloadIdentifier</key>
<string>JoedeMacBook-Pro.E7C9AC85-A3DC-48F4-BBB5-7ED71CC3C703</string>
<key>PayloadRemovalDisallowed</key>
<false/>
<key>PayloadType</key>
<string>Configuration</string>
<key>PayloadUUID</key>
<string>5F787710-4CD2-4453-9F79-DB2BF0A0235D</string>
<key>PayloadVersion</key>
<integer>1</integer>
</dict>
</plist>
```
> 2. 
    
## 参考
1. [Does NetworkExtension know which app the data flow comes from?](https://forums.developer.apple.com/thread/107013)
2. [NETunnelProviderManager](https://developer.apple.com/documentation/networkextension/netunnelprovidermanager)
3. [NEAppProxyProvider](https://developer.apple.com/documentation/networkextension/neappproxyprovider)
4. [Re: Must NEAppProxyProvider be used with MDM/VPN?](https://forums.developer.apple.com/message/227166#227166)
5. [NEAppProxyProviderManager](https://developer.apple.com/documentation/networkextension/neappproxyprovidermanager?changes=_8) 
6. [SimpleTunnel阅读笔记](https://github.com/nixzhu/dev-blog/blob/master/simple-tunnel.md)
