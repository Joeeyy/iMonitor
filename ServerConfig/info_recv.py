# coding=utf-8
from socket import *
from multiprocessing import Process
import time
import json
import os

log_path = "/home/ainassine/iTMlogs/"

def main():
    tcpSocket = socket(AF_INET, SOCK_STREAM)
    # reuse binding information so as to avoid waiting for 2*MSL time.
    tcpSocket.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
    address = ('', 7788)
    tcpSocket.bind(address)
    tcpSocket.listen(5)
    try:
        while True:
            time.sleep(0.01)
            print('waiting for connections...')
            newData, newAddr = tcpSocket.accept()
            print('%s a client has come, preparing to receive data...' % newAddr[0])

            p = Process(target=recv, args=(newData, newAddr))
            p.start()

            newData.close()
    finally:
        tcpSocket.close()


def recv(newData, newAddr):
    while True:
        recvData = newData.recv(1024)
        if len(recvData) > 0:
            print(recvData)
            #print(type(recvData))
            try:
                data_dict = json.loads(recvData)
            except:
                continue
            app_name = data_dict["app"]
            idfa = data_dict["idfa"]
            record = data_dict["record"]
            path = log_path + idfa + "/"
            if not os.path.isdir(path):
                os.mkdir(path)
            file = path + app_name + ".log"
            with open(file,'a') as f:
                f.write( json.dumps(record) + "\n")
            
            
        else:
            print('%client has disconnected ' % newAddr[0])
            break
    newData.close()


# tcpSocket.close()
if __name__ == '__main__':
    main()
