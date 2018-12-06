# iOS上基于NetworkExtension的实现流量分类的系统

> 备注信息，后续删除
> 
> 命名：iTrafficeClassifier
> 
> iOS app服务器：app.ainassine.cn
> 
> app下载地址：https://app.ainassine.cn/download.html
> 
> app.ainassine.cn => 119.23.215.159
> 
> PerAppProxy端口：10808
> 
> bundleID查询地址：http://www.ainassine.cn/AppStore\_Crawler_Demo/index.html
> 
> bundleID查询服务器端口：5000
> 
> 目前在iOS <= 12.1版本上`PerAppProxy`存在漏洞，在`iOS 12.1.1 beta 2`版本上有修复，如果用户需要使用基于`UDP`协议实现的语音、视频通话的话，需要升级至`iOS 12.1.1 beta 2`，否则会引起iPhone重启。

## 0x00 概述
> 项目需求背景描述，工具功能概述，工具运行环境概述，限制概述。

随着信息技术的不断发展，互联网用户的人数也在不断增多。更多技术上的创新，更多新设备的研发，让人们在接入互联网的方式上有了更多的选择。现如今，人们接入互联网的方式已经不再仅仅局限于桌面浏览器，更多移动设备，比如手机、平板等，给人们提供更多更加便利的上网方式。「论证以上」  
在移动设备上，接入互联网主要以APP的形式，当然诸多浏览器也算是APP的一种。现行主流移动端操作系统主要分为Android和iOS两大阵营，无论在哪一阵营中，其中的APP功能遍及到人们日常工作生活的方方面面，可以说现代人的生活已经越来越离不开这些APP。APP数目多，种类多，与使用者关系十分密切，有研究者证实，通过用户移动设备的APP安装情况可以分析出这个用户的人物画像，包括人物性格、喜好，乃至政治倾向、性取向可以被分析出来。移动APP涉及到金融交易、社交信息等各种极为敏感的数据，也使自己成为了无数灰黑产人员眼中的目标，导致移动APP的信息安全受到极大的关注。  
有关移动流量分析已经有前人做了大量工作。「举例」但是这些工作主要集中在Android平台上，对iOS涉及较少。虽然流量产生于平台并在平台之间进行交流，但是不同平台由于语言不通，同一个APP在实现的时候会产生变化，而且来自不同平台的流量会有不同的特征，如果不实际验证并不能保证理论的完全正确性。  
本文提供了一套名为iTrafficClassifier的系统，在iOS平台上搭建起了一套用于流量分析的系统。先前在iOS平台上并没有类似的尝试，可以说是iOS平台上第一个有效的工具。本工具基于iOS 9.0+的NetworkExtension API，实现了对iOS设备上流量的分析。可以为以下研究提供有效的支撑：1. 流量分类，本系统可以抓取特定APP的流量，并且进行标记，保证流量的纯净；2. 本系统将流量抓取与定位相结合，能够为流量数据与地理位置之间的联系的研究提供有效支持；3. 同样，我们可以实现内容拦截功能。4. 我们可以给用户展现其流量的具体使用情况，弥补了相关的不足。

## 0x01 系统架构
\![](https://raw.githubusercontent.com/Joeeyy/test/master/system%20arch.png)
客户端设计、功能，服务器设计、功能，客户端服务器通信设计。

客户端主要功能模块由PacketTunnel、PerAppProxy支撑。

> TODO：
> 
> ~~1. 百度地图API接入完成位置信息获取~~  
> 2. ContentFilter接入完成内容过滤

服务器主要包括**代理服务器**、**BundleID查询服务器**、**应用服务器**、**流量抓取服务器**等。

代理服务器完成SOCKS5协议通信。

BundleID查询服务器使用频率应该不高，属于附属产品，可以提供给其他用户查询某些中国区APP的bundle ID，由Python 3.6.5 提供服务。对于本系统，主要承担在iOS端工具编译时提供目标的bundle ID的任务。

应用服务器是为了支撑iOS端工具使用而建立的一系列脚本的集合。
> 目前阶段：
> 
> 1. 确定APP终端所在公网IP（IP+端口，如果终端在局域网环境中的话）。
> 2. 接收定位数据，并按照imei号码存储。
> 

流量抓取服务器主要完成对SOCKS5服务器转发的流量的抓取工作。
> 在这个过程中，明确的应该是目的应用服务器（终端上APP真正请求的服务器）的地址。由此就可以完成**服务器地址**和**应用**的对应关系的确定。

## 0x02 客户端
### 流量标记
利用iOS提供的[NetworkExtension](https://developer.apple.com/documentation/networkextension)中的`PerAppProxy`，我们可以以`NEAppProxyFlow`的形式获取目标APP的通信流量信息，包括流量来自哪个APP的信息，由此完成流量的按APP标记工作。`metaData.sourceAppSigningIdentifier`是我们获取源APP信息的属性，获取之后的标志符是以`BundleID`的形式呈现的，所以我们需要获取一些目标APP的`BundleID`，参看[BundleID查询服务器](#BundleID查询服务器)。

\![](https://raw.githubusercontent.com/Joeeyy/test/master/clientStructure.png)  
上图展示了客户端上流量标记的工作原理。以出方向的流量为例，符合`PerAppProxy规则`的来自上层APP的流量会被以`NEAppProxyFlow`的形式转发到`PerAppProxy`模块进行处理，而相关处理的主要实行者就是`PerAppProxy Provider`。在这个层面上已经能够获取流量的大部分信息，其中最为主要的用来确定流量来自哪个APP的`metaData.sourceAppSigningIdentifier`已经能够获取，但是流量的IP信息事实上还不能够完全确定。对于TCP流量来说，我们可以通过将`NEAppProxyFlow`转为`NEAppProxyTCPFlow`获得其`remoteEndpoint`属性，从而得知`NEAppProxyFlow`的目的地地址，但是`NEAppProxyTCPFlow`没有提供相对应的`localEndpoint`属性，当然如果只是对流量做标记的话我们对本地地址关心的程度并不是很大，但是我们依然可以通过一些方法来获得本地的IP地址，比如通过`createTCPConnection`函数与服务器建立一个TCP连接，从而可以通过该连接获得本地IP地址，不过如果终端在局域网环境下，这种方法仅能获得终端的局域网地址，如果需要公网IP，可以通过本系统中实现的[公网IP确定服务器](#公网IP确定服务器) 来完成。对于UDP流量来说，与TCP流量恰恰相反，当我们把`NEAppProxyFlow`转为`NEAppProxyUDPFlow`后，我们只能获得其`localEndpoint`属性，而无法获得`remoteEndpoint`属性，只有我们读出`NEAppProxyUDPFlow`中的datagrams后，才能获得这些datagrams的目的地址。之后根据流量协议的不同，经由`SOCKS5 Tunnel`按照不同的协议流程发往代理服务器，并在发送的同时在本地数据库中记录流量的信息，完成流量的标记工作。

### 位置记录
利用[百度定位SDK](http://lbsyun.baidu.com/index.php?title=ios-locsdk/guide/create-project/manual-create)实现。百度对iOS原生的定位服务进行了封装，在其基础上提供了语义化的定位结果，但是百度没有对iOS中[allowdeferredlocationupdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/1620547-allowdeferredlocationupdates)的函数进行封装，导致如果本APP被杀死，将无法继续进行定位服务。**但是只要程序在后台，就能保证长期活动**。

*定位返回数据*<br>
1. location: <br>
  
  > location是iOS原生的定位结果，属于[CLLocation](https://developer.apple.com/documentation/corelocation/cllocation)类型。以下内容均可以在[CLLocation](https://developer.apple.com/documentation/corelocation/cllocation)中找到，有更详细了解的需求请移步。
  
  **主要属性**：<br>
  `coordinate: CLLocationCoordinate2D`: 定位获得的二维地理坐标，经纬度。<br>
  `altitude: CLLocationDistance`: 定位获得的海拔高度。<br>
  `horizontalAccuracy: CLLocationAccuracy`: 水平定位精度，单位为`米`。<br>
  `verticalAccuracy: CLLocationAccuracy`: 垂直定位精度，单位为`米`。<br>
  `floor: CLFloor?`: 定位获得的楼层数，不是所有定位都有结果，也不是所有的iPhone都支持。<br>
  `speed: CLLocationSpeed`: 定位获得的设备移动速度，单位为`米每秒`。<br>
  `course: CLLocationDirection`: 定位获得的设备的方向，以与正北方向的相对夹角衡量。<br>
  `timestamp: Date`: 定位结果产生的时间点。<br>
  <br>
2. rgcData: <br>
  > rgcData属于Baidu定位SDK定义的[BMKLocationReGeocode](http://wiki.lbsyun.baidu.com/cms/iosloc/docs/v1_2_1/html/interface_b_m_k_location_re_geocode.html)类，是对iOS定位结果的一种补充，对定位结果进行了语义解释。
  
  `country: NSString`: 定位所在的国家。<br>
  `countryCode: NSString`: 国家编码。<br>
  `province: NSString`: 省份名称。<br>
  `city: NSString`: 城市名称。<br>
  `district: NSString`: 区名称。<br>
  `street: NSString`: 街道名称。<br>
  `streetNumber: NSString`: 街区号码。<br>
  `cityCode: NSString`: 城市编码。<br>
  `adCode: NSString`: 行政区划编码。<br>
  `locationDescribe: NSString`: 定位地点在什么地方周围的语义化描述信息。
  `poiList: NSArray<BMKLocationPoi*>`: 语义化结果，表示该定位点周围的poi列表。

<span id="定位数据上传">
*定位数据上传*<br>
定位数据是由BaiduLocation SDK产生的，每隔大约15s会有一次定位结果。本APP不在手机上保留定位结果，在获得定位结果后就通过HTTP POST以JSON的形式上传到服务器，JSON格式如下：

```
{
  "idfa": xxxxxxxxx,
  "location": {
    "coordinate": (double,double),   
    "horizontalAccuracy": double,   
    "altitude": double,
    "verticalAccuracy": double,
    "floor": int?,
    "speed": double,
    "course": double,
    "timestamp": Date
  },
  "rgcData": {
    "country": String,
    "countryCode": String,
    "province": String,
    "city": String,
    "cityCode": String,
    "district": String,
    "street": String,
    "streetNumber": String,
    "adCode": String,
    "locationDescribe": String,
    "poiList": list,[]cd 
  }
}
```
~~其中`imei`用于确定iPhone终端。也可以获得设备的`UUID`作为唯一标志。~~  
根据[iOS - 获取设备标识符UUID/UDID/IMEI等](https://blog.csdn.net/Sir_Coding/article/details/68943033)，iOS上获取`IMEI`、`IMSI`、`UDID`已经不再可能。而`UUID`作为唯一标志符比较繁琐，参考[获取iOS设备唯一标示UUID——Swift版](https://www.jianshu.com/p/9e885c3e6b0a)这里使用`IDFA`作为唯一标志符，**要求用户允许追踪**。`IDFA`会在用户卸载iPhone上所有相关开发商的APP后重置。`353B317C-0B24-4C0F-B840-92A77F6350BC`是一个样例。

### 内容过滤

### 数据库



## 0x03 服务端
### 代理服务器
> 服务器地址：119.23.215.159:10808  

SOCKS5服务器源码来自[Github](https://github.com/postageapp/ss5)。为了适应aliyun服务器*专用网络*没有公网网卡的缺陷，改动了其中开启UDP服务的代码，使其监听端口为`0.0.0.0`而非某个公网IP。根据[StackOverflow](https://stackoverflow.com/questions/53361320/is-there-a-timeout-for-udp-in-socks5)，为了保证UDP通话通畅进行，修改了SOCKS5实现中关于UDP连接超时的设置，由原来的`60`修改为`6000`，单位为`秒`。  
**SOCKS5参考**  
[RFC 1928](https://www.ietf.org/rfc/rfc1928.txt)，定义了`SOCKS5`协议的基本通信流程。  
[RFC 1929](https://tools.ietf.org/html/rfc1929)，`SOCKS5`用户名密码认证过程。  
[RFC 1961](https://tools.ietf.org/html/rfc1961)，`SOCKS5`GSS-API方式认证过程。

### 流量抓取服务器
> 利用TCPDump配合脚本实现<br>
> -d、-dd、-ddd意义不明。<br>

*TCPDump的使用*：<br>
参照[说明](http://www.tcpdump.org/manpages/tcpdump.1.html)。

*重要选项*：<br>
`-w file`：保存抓取结果到文件*file*中。<br>
`-B buffer_size`或`--buffer-size=buffer_size`：设置操作系统抓取的缓冲区大小，单位为KiB（1024字节）。<br>
`-c count`：抓取*count*个packet后退出。<br>
`-C file_size`：在向文件写入一个新的packet前，检查文件大小是否超过*file_size*设置，如果超过，则关闭当前文件并打开一个新的文件进行写入。后续文件命名为`-w`设定的文件名加序号。*file_size*的单位为**百万字节**（1,000,000字节，而非1,048,576字节）。<br>
`-D`或`--list-interfaces`：列出系统中可用的网络接口，以及在哪些接口上可以进行流量抓取。对于每个接口，会打印序号、接口名，可能还会打印有关接口的描述信息。接口名或者接口序号可以被提供给`-i`参数用来指定在哪个接口上进行流量抓取。如果*tcpdump*在编译过程中使用的*libpcap*过老，缺少[pcap_findalldevs](http://www.tcpdump.org/manpages/pcap_findalldevs.3pcap.html)(3PCAP)函数，`-D`参数将不被支持。<br>
`-F file`：使用*file*作为输入的正则式文件。<br>
`-i interface`或`--interface=interface`：监听*interface*。如果没有设置，*tcpdump*将寻找系统中序号最小的接口（本地回环除外）进行监听，结果很有可能是`eth0`。<br>
`-n`：不要将地址转为名称，比如将IP、端口号转为域名。<br>
`-Q direction`或`--direction=direction`：选择抓取报文的方向为*direction*，有*in*、*out*、*inout*可选。不是所有的平台都支持。<br>

*执行设计*：<br>
首先我们的流量是来自客户端，经由SOCKS5协议传输到服务器上，再由服务器与目的服务器进行通信的。这其中设计很多packet换头的操作。在我们的SOCKS5服务器看来，无论客户端身处什么样的网络环境（客户端有可能身处某内网，本身IP是局域网IP），他都只能看到该客户端在公网上的IP和端口，而客户端需要进行交互的服务器无疑是暴露在公网上的，也就是说，目的服务器的IP、端口与其提供的服务之间存在着长期、稳定的对应关系，这样我们就能完成**流量的APP分类**。那么如何在抓取后区别来自不同的客户端的流量呢？在比较粗略的粒度上，如果终端是通过运营商网络直接接入互联网，那么他的IP地址就是其自身的真实IP地址。但是如果终端是经由路由器之类的设备接入网络，那么只有通过其IP地址和端口号去鉴识其身份。现在系统内只是简单获取终端的公网IP，后续需要尝试获取公网IP、端口号，并且证实这一对应关系的正确性。终端需要周期上报自身的特征以及IP。

> **一个示例的tcpdump执行命令**<br>
> tcpdump -w t.pcap -C 1 [expression]<br>
> *tcpdump*将会抓取满足expression的流量，并将结果保存在*t.pcap*中，如果*t.pcap*大小超过了1百万字节（约为1MB），那么就会保存在新的文件t.pcapnum中，其中num从1自增。<br>
> 
> **关于expression**<br>
> 沟通需求后再确定，目前来看可以只抓ipv4的部分。


<span id="BundleID查询服务器">
### BundleID查询服务器
> 地址：http://www.ainassine.cn/AppStore\_Crawler_Demo/index.html

为了更方便的实现查询iOS APP的`BundleID`，本人写了一个`APP Crawler`放在[Github](https://github.com/Joeeyy/app_crawler)上。相关细节后续补上。

### 应用服务器

#### 1 定位数据接收服务器
> 地址：  
> http://119.23.215.159/test/checkin/locRec.php  
>   
> 服务器操作系统：  
> LSB Version:	:core-4.1-amd64:core-4.1-noarch  
> Distributor ID:	CentOS  
> Description:	CentOS Linux release 7.2.1511 (Core)  
> Release:	7.2.1511  
> Codename:	Core  
> 
> apache版本：
> Server version: Apache/2.4.6 (CentOS)  
> Server built:   Jun 27 2018 13:48:59  
> 
> PHP版本：
> PHP 5.4.16 (cli) (built: Apr 12 2018 19:02:01)  
> Copyright (c) 1997-2013 The PHP Group  
> Zend Engine v2.4.0, Copyright (c) 1998-2013 Zend Technologies  

定位数据以`JSON`格式通过`HTTP POST`方式上传到服务器。服务器采用PHP实现，负责接收数据，并且以`locRec{UUID}.log`的形式对不同iPhone终端的定位数据进行保存。样例请看[这里](https://app.ainassine.cn/test/checkin/locRec353B317C-0B24-4C0F-B840-92A77F6350BC.log)。

<span id="公网IP确定服务器">
#### 2 公网IP确定服务器
> 地址：  
> http://119.23.215.159/test/checkin/checkin.php

类似定位数据接收服务器，应用在启动后会以`HTTP POST`的形式，带自己的`UUID`请求服务地址，从而获得自己的`公网IP`地址。。

#### 3 流量标记上传服务器

## 0x04 通信设计

流量分类信息通信。==[待实现]==

### 位置信息通信
参照[定位数据上传](#定位数据上传)

## 0x05 应用分析
客户端开销 ==[TODO]==

服务器容量 ==[TODO]==

## 0x06 成果对比

## 0x07 参考
[1] [Reboot caused by my AppProxy handling UDPFlows](https://forums.developer.apple.com/message/339578#339578)<br>
[2] [Does NetworkExtension know which app the data flow comes from?](https://forums.developer.apple.com/thread/107013)<br>
[3] [SOCKS5 Server](https://github.com/postageapp/ss5)<br>
[4] [Is there a timeout for UDP in SOCKS5?](https://stackoverflow.com/questions/53361320/is-there-a-timeout-for-udp-in-socks5)<br>
[5] [RFC 1928](https://tools.ietf.org/html/rfc1928)  
[6] [RFC 1929](https://tools.ietf.org/html/rfc1929)  
[7] [RFC 1961](https://tools.ietf.org/html/rfc1961)  


智能机用户情况：https://venturebeat.com/2018/09/11/newzoo-smartphone-users-will-top-3-billion-in-2018-hit-3-8-billion-by-2021/


## 一些文献

### Robust Smartphone App Identification Via Encrypted Network Traffic Analysis
时间：09 August 2017  
作者：https://ieeexplore.ieee.org/abstract/document/8006282/authors  
发表于：IEEE Transactions on Information Forensics and Security  

提出了一种利用机器学习技术基于旁路数据（加密报文的长度、方向）对APP进行指纹提取和识别的技术，并对APP指纹在不同时间、不同设备、不同版本APP中的变化。

效果，测试了110中Google商店上流行的APP，并能在六个月后以96%的准确率识别他们。

介绍：
1. 智能机的消费增速快。引用Gartner的调查结果。[1]
2. APP使用广泛。引用Flurry的调查结果。[2]
3. 使用者花费大量时间在众多APP上。引用Nielson的调查结果。[3]
4. 智能机现在是接入互联网的最普遍方式。引用Guardian的调查结果。[4]
5. 智能机产生的流量是台式机、平板、移动路由设备产生的流量的和的两倍。引用Telegraph的调查结果。[5]
6. 以上各点将智能机置于所有想要研究公众流量的人的焦点中。

1. 通过一个人装的APP可以对人物进行画像。[6]
2. 网络流量指纹提取是近年的新领域。机器学习的手段可以应用到该领域上。[7]
3. 近年APP的指纹提取和识别在以下几种方法上没有取得进展：基于端口的指纹提取（由于APP主要基于HTTP和HTTPS进行数据传输）,经典的网页指纹提取（由于APP总是以XML、JSON这样的文本形式进行数据传输，其中不含富文本信息），CDN的使用使得域名解析、IP地址查询、DNS解析或者TLS握手无法被用作鉴定根据。
4. 本文提供的技术的应用场景：针对特定APP的攻击，针对特定用户的攻击，网络管理，广告和市场营销。
5. 是对AppScanner，应用扫描框架，的扩展。[8]

相关工作
1. 工作站和浏览器的流量分析已经有很多工作。[9]
2. 智能机的流量通信与工作站和浏览器的流量分析有不同。[10]-[13]

流量分析方法
1. 工作站上传统的流量分析方法。

智能机流量分析的方法
NetProfiler，使用一种UI Fuzzing的方法来模拟在一个APP上的操作，并同时记录log和流量。他们分析的是Payload。[20]
提出了一种利用设备产生的特殊流量模式识别整个设备的框架。训练时间长。[21]
提出了一种能够从加密的802.11帧中识别智能机APP的系统。但是系统测试样本小，长时间训练反而会产生副作用。[22]
they have no way to collect accurate ground truth, i.e., a labelled dataset that is free of noise from other apps.
！！！虽然本系统声称“Indeed, our methodology minimises noise by running a single app at a time, and we still had to filter 13% of the traffic collected because it was background traffic from other apps.”，他们始终无法保证app的流量的纯洁性。

***

### AntMonitor: A System for Monitoring from Mobile Devices
时间：August 17 - 17, 2015  
发表于：C2B(1)D '15 Proceedings of the 2015 ACM SIGCOMM Workshop on Crowdsourcing and Crowdsharing of Big (Internet) Data

AntMonitor - Android设备上被动流量分析的系统。
给用户对监控数据的选择权  
不需要root  
支持客户端流量分析  
支持大量的、细粒度的、富含语义的流量收集。

能够支撑以下几个研究方面：
1. 从边缘进行网络测量
2. 移动流量分析
3. 隐私泄露检测和一些其他的可疑行为

介绍  
大规模上  
细粒度上  
对用户的吸引性上  

### PrivacyGuard: A VPN-based Platform to Detect Information Leakage on Android Devices
时间：October 12 - 12, 2015  
发表于：SPSM '15 Proceedings of the 5th Annual ACM CCS Workshop on Security and Privacy in Smartphones and Mobile Devices
Pages 15-26  

