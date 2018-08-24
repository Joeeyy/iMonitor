#  testVPN 

## 进度
1. 2018-08-20  testVPN 框架
    完成testVPN中关于vpn配置的若干操作。
2. 2018-08-21 testVPN 测试用APP：MakePost
    完成名为MakePost的测试用APP，主要用于简单化网络请求发送，有利于后续的功能呢测试工作。
3. 2018-08-24 testVPN 服务代码完成
    完成testVPN 中服务性质代码的编写。
    testVPNServices中的`util.swift`、`Tunnel.swift`、`ClientTunnel.swift`、`Connection.swift`
    `util.swift`是公用代码，内涵普遍用到的工具类、工具方法等
    `Tunnel.swfit`是隧道基类，定义了最为基础的隧道
    `ClientTunnel.swift`是对客户端隧道的定义
    `Connection.swift`是对连接的定义
4. 2018-08-24 晚 开始着手packetTunnelProvider类的实现。
    
    

## 参考
