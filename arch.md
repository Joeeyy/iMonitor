#  系统架构文档

## 总体架构

> testVPN分为客户端、服务器两块内容，客户端是由swift编写、安装在iOS设备上的以APP形式提供服务的程序，服务器也是通过swift编写，但由于调用了MacOS的API只能运行在MacOS上的命令行工具。
> 系统最关键的功能：
> 在手机端通过per-app proxy实现对特定app流量的标记，per-app proxy管理的app的流量会从packet tunnel走向我们的服务器，就是所谓的VPN的过程。在服务器端进行流量抓取，结合手机采集的流量信息总结出的过滤条件将相应的app的流浪过滤出来，完成大部分需求。
> 核心API，Apple提供在MacOS和iOS的NetworkExtension，主要调用其中的AppProxy和PacketTunnelg模块（客户端）。

## 关于服务模块

### util
1. 定义了SimpleTunnelError：badConfiguration、badConnection、internalError
2. 定义了SavedData类：定义了大块数据的队列。
    chain: 实现队列的主要模块。
    isEmpty: 队列是否为空。
    append(): 向队列的尾部添加一个元素。
    writeToStream(): 向输出流中写入尽量多的数据。
    clear(): 清空chain。
3. 定义了SocketAddress6类：定义ipv6的结构。
4. 定义了SocketAddress类：定义了ipv4的结构。
5. saToString: socketAddress to string。
6. writeData(): 从某个特定的offset写入data blob。
7. createMessagePropertiesForConnection：为某个Connection封装发送的数据。
8. SettingsKey: 枚举了[7]中所有可能出现的配置键值。
9. getVaueFromPlist(): 从plist中获取指定的key的值。
10. rangeByMovingStartOfRange(): 通过对某个给定的范围增加一个指定的值来实现建立一个新的范围。
11. getTime(): 返回一个yyyy-MM-dd HH:mm:ss.SSSSSS格式的时间戳。
12. getIFAddresses(): 获取iPhone本机ip地址。
13. postRequest(): 发送POST请求。
14. 定义Netlog数据类。
15. testVPNLog()和simpleTunnelLog()：进行日志记录的方法。

### Tunnel
隧道父类
1. 枚举了SimpleTunnel协议中可能出现的九个指令以及相应的指令序号。
2. 枚举了SimpleTunnel协议中消息字典中可能出现的键的名称。
3. 枚举了SimpleTunnel协议中两种隧道工作的协议层。
4. 枚举了SimpleTunnel协议中AppProxyFlow可能出现的两种类型。
5. 声明了Tunnel的代理协议接口。
6. 以下为Tunnel类内容。
属性：
delegate：Tunnel类的代理对象。
connections：tunnel中已经开启的逻辑连接。
savedData：tunnel中等待写入的数据。
serviceType：定义了Tunnel的Boujour Service字符串。
serviceDomain：定义了Tunnel的Boujour Service的域。
maximumMessageSize：定义了SimpleTunnel最大的消息大小。
packetSize：定义了单个SimpleTunnel的IP数据包的最大大小。
maximumPacketsPerMessage：定义了一个SimpleTunnel数据消息中IP数据包的最大数目。
allTunnels：所有tunnel的列表。
函数：
init(): 构造器，每个Tunnel在初始化的时候应当将自己加入到allTunnels列表中。
closeTunnel(): 关闭tunnel。1. 关闭所有的连接。2. 清空所有数据。3. 移除所有tunnel
addConnection(): 在tunnel中添加一个connection。
dropConnection(): 丢弃tunnel中某一特定connection。
closeAll(): 关闭所有已经打开的tunnel。
writeDataToTunnel(): 向tunnel中写输入数据。
serializeMessage(): 根据传入的消息属性将消息序列化，其中涉及到SimpleTunnel协议的报文格式。
sendMessage(): 发送一条消息。
sendData(): 发送一套数据消息。
sendDataWithEndPoint(): 向指定终端发送一条数据消息。
sendSuspendForConnection(): 在指定连接中发送suspend消息。
sendResumeForConnection(): 在指定连接中发送resume消息。
sendCloseType(): 在指定连接中发送关闭消息，指定关闭方向。
sendPackets(): 发送报文。
handlePacket(): 处理接收的报文。
handleMessage(): 处理接收到的消息。

### ClientTunnel
继承自Tunnel，客户端隧道类。
1. 将NEVPNState转化为字符串
2. 以下为ClientTunnel类内容。
属性：
connection: 这是一个TCPConnection。
lastError: 连接上出现的最后一个错误。
previousData: 之前收到的不完整的消息数据。
remoteHost: tunnel server的地址。
函数：
startTunnel(): 开启与服务器之间的TCP连接。
closeTunnel(): 关闭与服务器之间的连接。
closeTunnelWithError(): 出现错误时关闭Tunnel。
readNextPacket(): 从SimpleTunnel连接上读取消息。
sendMessage(): 发送消息给tunnel_server。
observeValue(): 监听连接的状态变化。
writeDataToTunnel(): 向tunnel中写入数据。
handleMessage(): 处理服务器发来的消息。
sendFetchConfiguration(): 向服务器发送获取配置的请求。

### Connection
1. 枚举了连接中所有可能的关闭的方向。
2. 枚举了一次连接开启活动所有可能导致的结果。
3. 以下为Connection类。
属性：
identifier: 区分不同连接的标志序号。
tunnel: 连接所属的tunnel。
savedData: 连接上等待写入的数据。
currentCloseDirection: 连接当前关闭的方向。
isExclusiveTunnel: 指示当前tunnel是否为连接排他性地使用。
isClosedForRead: 指示当前连接是否关闭了读方向。
isClosedForWrite: 指示当前连接是否关闭了写方向。
isClosedCompletely: 指示当前连接是否关闭了读写方向。
函数：
init(): 构造器。
setNewTunnel(): 给连接设置一个新的所属tunnel。
closeConnection(): 将连接从某个方向关闭。
abort():
sendData():
sendDataWithEndPoint():
sendPackets():
suspend():
resume():
handleOpenCompleted():


## 关于客户端

### AppProxy
1. AppProxyProvider：
是AppProxy的服务提供者，属于系统中最为上层的部分，负责感知、处理系统中由AppProxy管辖的流量。

属性：
    tunnel，属于ClientTunnel，是隧道的对象。
    pendingStartCompletion，处理tunnel完全建立的handler。
    pendingStopCompletion，处理tunnel完全终止的handler。
    
函数：
startProxy(): 建立新的tunnel，并尝试启动该tunnel，在启动成功后便赋值给AppProxyProvider的tunnel。
stopProxy(): 清空completionHandler，并关闭tunnel。
handleNewFlow(): 处理来自Proxy管理的APP的一条流。按照该流的类别（TCP或者UDP）分别建立不同类型的连接，该连接是Tunnel的内置属性。

代理：（隧道代理）
tunnelDidOpen(): 处理tunnel开启的代理，在开启之后向客户端发送请求配置的信息。
tunnelDidClose(): 处理tunnel关闭的代理，主要是调用合适的completionHandler。
tunnelDidSendConfiguration(): 处理系统服务器发来的配置信息。1. 获取tunnel远端（服务器）地址。2. 获取配置信息中的DNS字典。3. 建立新的Tunnel配置。4. 按照配置进行设置。
handleAppMessage(): override
sleep(): override
wake(): override

2. ClientAppProxyConnection：
内含ClientAppProxyConnection、ClientAppProxyTCPConnection、ClientAppProxyUDPConnection三个类，均继承自Connection类。
> 0x00 ClientAppProxyConnection.
> 属性：
>     appProxyFlow: 该连接所传输的一条流。
>     queue: ClientConnection中数据的调度队列。
> 函数：
>     init(): 构造器，确定该Connection对应的Tunnel和AppProxyFlow。
>     open(): 发送open信息给服务器，以开始SimpleTunnel协议下一条数据流的传输过程。
>     open(extraProperties: ): 发送带参数的open信息，以开始SimpleTunnel写一下一条流（数据流或者控制流）的传输过程。
>     handleSendResult(): 处理发送消息的结果，主要是对error信息的处理。
>     handleErrorCondition(): 处理连接上的错误。
>     sendDataMessage(): 发送数据流。1. 挂起队列，保证自己发送完成之前不会有其他的数据被写入tunnel。2. 将data写入协议的payload。3. 填充协议中其他的部分。4. 发送数据，完成后恢复队列，调用handleSendResult处理返回信息。
> 关于Connection管理：
>     handleOpenCompleted(): 处理服务器发来的结果，主要是对.success的处理，如果成功则获取localAddress，并根据localAddress开启appProxyFlow。
>     closeConnection(): 根据不同方向关闭连接。

> 0x01 ClientAppProxyTCPConnection.
> 属性：
>     TCPFlow: 将appProxyFlow特定化为TCPFlow。
> 函数：
>     init(): 构造器，以Tunnel和Flow为传入参数进行TCPConnection构造。
>     open(): 向服务器发送open消息，开始一段TCP数据的传输。内部调用父类的open函数传递参数，参数内容：app 层、Host、Port、FlowType。
>     handleSendResult(): 处理发送数据后的返回结果。1. 如果出现错误，处理错误。2. 没有错误的话继续读取剩余数据，进行发送。
>     sendData(): 向TCPFlow中写入data数据。

> 0x02 ClientAppProxyUDPConnection.
> 属性：
>     UDPFlow: 将appProxyFlow特定化为UDPFlow。
> 函数： 
>     init(): 构造器。
>     open(): 先服务器发送open消息，开始一段UDP数据的传输。内部调用父类的open函数传递参数，参数内容： app层、FlowType。
>     handleSendResult(): 处理发送数据后的返回结果。1. 如果出现错误，处理错误。2. 没有错误的话继续读取剩余数据，进行发送。
> sendDataWithEndPoint(): 带终端节点进行数据发送。

### PacketTunnel
1. PacketTunnelProvider：
属于所谓的VPN服务的提供者，为AppProxy提供了下层Tunnel，经由AppProxy引导的流量会按照要求走指定的PacketTunnel。

属性：
tunnel: 一个ClientTunnel对象，是对应的VPN连接所拥有的Tunnel，是数据传输的通道。
tunnelConnection：一个ClientTunnelConnection对象，tunnel中传输的数据的逻辑流。
pendingStartCompletion：处理Tunnel开启完成消息的Handler。
pendingStopCompletion：处理Tunnel停止完成消息的Handler。
函数：
startTunnel(): 开启VPN隧道。建立一个ClientTunnel，并尝试开启，开启成功后将该ClientTunnel赋值给tunnel。
stopTunnel(): 关闭VPN隧道。
handleAppMessage(): 处理来自app发的消息。并回应。这里主要是一种激活的作用。其实没有也没问题？
代理：
tunnelDidOpen(): 处理tunnel开启的handler，在tunnel开启后开启一个ClientConnection，该ClientConnection即为PacketTunnelProvider的clientTunnelConnection。
tunnelDidClose(): 处理tunnel关闭的handler。
tunnelDidSendConfiguration(): 暂时空函数。
tunnelConnectionDidOpen(): 处理tunnel中逻辑连接建立完成。1. 建立配置。2. 设置配置。
tunnelConnectionDidClose(): 处理tunnel中逻辑连接关闭。
createTunnelSettingsFromConfiguration(): 从配置中创建隧道设置。

2. ClientTunnelConnection：
定义了ClientTunnelConnection的代理协议，以及ClientTunnelConnection。
属性：
delegate: clientTunnelConnection的代理。
pakcetFlow: 链接内流通的数据包流。
函数：
init(): 构造器。
open(): 发送开启信息。
startHandlingPackets(): 开始读取数据包。
handlePackets(): 处理一个数据包。packetFlow().readPackets() -> pakcets, protocols. 
sendPackets(): 向packetFlow()写入数据。
handleOpenCompleted(): 处理open消息d返回的结果。


## 关于服务器

### AddressPool
用于管理IP地址池。
属性：
baseAddress：IP起始地址。
size：IP池的大小
inUseMask：用于记录IP使用情况的列表。
queue：对地址池访问的调度队列。
函数：
init(): 构造器。1. 设定起始地址、结束地址。2. 设置地址池大小。3. 初始化inUseMask。
allocateAddress(): 进行地址分配。返回一个可用的地址。
deallocateAddress(): 收回一个已经分配的地址。

### ServerConfiguration
服务器配置对象。
属性：
configuration: 含有配置的字典。
addressPool: 服务器的地址池。
函数：
init(): 构造器。configuration的声明和addressPool的置空。
loadFromFileAtPath(): 从指定路径的文件中读取配置。
copyDNSConfigurationFromSystem(): 从系统配置中拷贝DNS配置。

### ServerConnection
属性：
readStream: 输入流。
writeStream: 输出流。 
函数：
open(): 开启通向某一地址的连接。
closeConnection(): 关闭连接。
abort(): 
suspend(): 
resume(): 
sendData(): 
代理：
stream(): 处理流上可能出现的各种情况。

### ServerTunnel
属性：
readStream: 输入流。
writeStream: 输出流。
packetBuffer: 数据包缓冲。
packetBytesRemaining: 当前数据中剩余的未读流量。
serviceDelegate: 服务器网络服务的代理。 
函数：
init(): 构造器。
startListeningOnPort(): 注册NetService，开始对端口的监听。
handleBytesAvailable(): 处理输入流上有数据出现的情况。
sendOpenResultForConnection(): 向某连接发送open请求的结果。
handleConnectionOpen(): 处理连接建立成功的情况。
closeTunnel(): 关闭隧道。
handleMessage(): 处理来自客户端的消息。
writeDataToTunnel(): 向tunnel中写入数据。
代理：
stream(): 处理流事件。
tunnelDidOpen(): 
tunnelDidClose():
tunnelDidSendConfiguration(): 

ServerDelegate类：
函数：
netService(): 处理publish失败的情况。 
netServiceDidPulish(): 处理publishi成功的情况。
netService(): 处理来了一个新的连接的情况。
netServiceDidStop(): 处理NetService停止的情况。

### ServerTunnelConnection
提供SimpleTunnel协议中数据包的逻辑流与UTUN接口之间连接的桥梁。
属性：
tunnelAddress: tunnel的虚拟地址。
utunName: UTUN忌口的名称。
utunSource: UTUN接口套接字的调度源。
isSuspend: 指示对UTUN的读取是否被挂起。
函数：
sendOpenResult(): 发送open请求的结果。
open(): 通过设置UTUN接口开启连接。
createTunInterface(): 建立额UTUN接口。
getTUNInterfaceName(): 获取某套接字关联的UTUN接口的名称。
setupVirtualInterface(): 建立虚拟UTUN接口，并开始读取数据包。
readPackets(): 从UTUN读取数据包。
startTunnelSource(): 开始从UTUN读取数据包。
abort():
closeConnection():
suspend():
resume():
sendPackets():

### UDPServerConnection
表示服务端的SimpleTunnel协议中的一条逻辑UDP网络数据。
属性：
addressFamily: UDP套接字地址族。
responseSource: 从UDP套接字读取数据的调度源。
函数：
init(): 构造器。
deinit(): 解构器。
getEndpointFromSocketAddress(): 获取地址。
createSocketWithAddressFamilyFromAddress(): 依据地址建立套接字。
sendDataWithEndPoint(): 发送数据。
closeConnection():

### main

### ServerUtils.h&m
getUTUNControlIdentifier():
setUTUNAddress():
getUTUNNameOption():
setSocketNonBlocking():

## 关于流量过滤
> 首先做定义，客户端的数据包地址信息定义为<client_ip, client_port>，本系统服务器的地址信息定义为<server_ip, server_port>，app的目的服务器地址信息定义为<dst_ip, dst_port>。
> 在服务器上可见的流量有两块。
> 1. 客户端与系统服务器之间的流量：client_ip:client_port <==> server_ip:server_port
> 2. 系统服务器与app目的服务器之间的流量：server_ip:server_port <==> dst_ip:dst_port
> 而如果除去我们的系统服务器的环节，正常化的流量应当是：client_ip:client_port <==> dst_ip:dst_port的

