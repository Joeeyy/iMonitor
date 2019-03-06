# ServerConfig

testVPN project will be renamed to iMonitor soon. iMonitor system will be composed of mainly a server and a client. Here is some details about that.

Server:  
  1) ss5 server
  		downloaded from [sourceforge](http://ss5.sourceforge.net), udp listen time has been modified and listening address is also modified.
  		usually ss5 server listens on 10808 for TCP connections.  
  		reference: [https://blog.csdn.net/Vincent95/article/details/71172986](https://blog.csdn.net/Vincent95/article/details/71172986).  
  2) info receiver (info_recv.py)
  		Listen port: 7788.
  		Save location of logs: defined by `"log_path"`, `/home/ainassine/iTMlogs/` by default.
  		Note: logs are saved in `log_path` separated by `idfa`.
  3) traffic catch: 
  		`tcpdump -w t.pcap -C 100`
  
Data process script:
  1) @[https://github.com/Joeeyy/pcapAnalyze](https://github.com/Joeeyy/pcapAnalyze)

Client:  
  1) iMonitor Client

Download & installation:  
  1) url: [https://app.ainassine.cn/download.html](https://app.ainassine.cn/download.html)  
  2) app installation: [itms-services://?action=download-manifest&url=https://app.ainassine.cn/manifest.plist](itms-services://?action=download-manifest&url=https://app.ainassine.cn/manifest.plist)  
  3）mobileconfig installation: [https://app.ainassine.cn/testVPN.mobileconfig](https://app.ainassine.cn/testVPN.mobileconfig)  
  `mobileconfig` file defines server address, which is `119.23.215.159:10808` at present.  

