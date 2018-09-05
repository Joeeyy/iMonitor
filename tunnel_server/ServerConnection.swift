/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the ServerConnection class. The ServerConnection class encapsulates and decapsulates a stream of network data in the server side of the SimpleTunnel tunneling protocol.
 */

import Foundation

/// An object representing the server side of a logical flow of TCP network data in the SimpleTunnel tunneling protocol.
class ServerConnection: Connection, StreamDelegate {
    
    // MARK: Properties
    private let TAG = "ServerConnection: "
    
    /// The stream used to read network data from the connection.
    var readStream: InputStream?
    
    /// The stream used to write network data to the connection.
    var writeStream: OutputStream?
    
    // MARK: Interface
    
    /// Open the connection to a host and port.
    func open(host: String, port: Int) -> Bool {
        testVPNLog(self.TAG + "ServerConnection \(identifier) connecting to \(host):\(port)")
        
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &readStream, outputStream: &writeStream)
        
        guard let newReadStream = readStream, let newWriteStream = writeStream else {
            return false
        }
        
        for stream in [newReadStream, newWriteStream] {
            stream.delegate = self
            stream.open()
            stream.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
        }
        
        return true
    }
    
    // MARK: Connection
    
    /// Close the connection.
    override func closeConnection(_ direction: TunnelConnectionCloseDirection) {
        testVPNLog(self.TAG + "closing the connection in the direction :\(direction.description)")
        super.closeConnection(direction)
        
        if let stream = writeStream, isClosedForWrite && savedData.isEmpty {
            if let error = stream.streamError {
                testVPNLog("Connection \(identifier) write stream error: \(error)")
            }
            
            stream.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
            stream.close()
            stream.delegate = nil
            writeStream = nil
        }
        
        if let stream = readStream, isClosedForRead {
            if let error = stream.streamError {
                testVPNLog("Connection \(identifier) read stream error: \(error)")
            }
            
            stream.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
            stream.close()
            stream.delegate = nil
            readStream = nil
        }
    }
    
    /// Abort the connection.
    override func abort(_ error: Int = 0) {
        testVPNLog(self.TAG + "abort the serverConnection.")
        super.abort(error)
        closeConnection(.all)
    }
    
    /// Stop reading from the connection.
    override func suspend() {
        testVPNLog(self.TAG + "Suspend, stopping reading from the connection.")
        if let stream = readStream {
            stream.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
        }
    }
    
    /// Start reading from the connection.
    override func resume() {
        testVPNLog(self.TAG + "Resume, starting reading from the connection.")
        if let stream = readStream {
            stream.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
        }
    }
    
    /// Send data over the connection.
    override func sendData(_ data: Data) {
        testVPNLog(self.TAG + "Send data over the connection \(self.identifier).")
        guard let stream = writeStream else { return }
        var written = 0
        
        if savedData.isEmpty {
            written = writeData(data as Data, toStream: stream, startingAtOffset: 0)
            
            if written < data.count {
                // We could not write all of the data to the connection. Tell the client to stop reading data for this connection.
                stream.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
                tunnel?.sendSuspendForConnection(identifier)
            }
        }
        
        if written < data.count {
            savedData.append(data as Data, offset: written)
        }
    }
    
    // MARK: NSStreamDelegate
    
    /// Handle an event on a stream.
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        testVPNLog(self.TAG + "connection \(self.identifier): handle an evenet on a stream")
        switch aStream {
            
        case writeStream!:
            testVPNLog(self.TAG + "it's an event of a writeStream")
            switch eventCode {
            case [.hasSpaceAvailable]:
                if !savedData.isEmpty {
                    guard savedData.writeToStream(writeStream!) else {
                        tunnel?.sendCloseType(.all, forConnection: identifier)
                        abort()
                        break
                    }
                    
                    if savedData.isEmpty {
                        writeStream?.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
                        if isClosedForWrite {
                            closeConnection(.write)
                        }
                        else {
                            tunnel?.sendResumeForConnection(identifier)
                        }
                    }
                }
                else {
                    writeStream?.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
                }
                
            case [.endEncountered]:
                tunnel?.sendCloseType(.read, forConnection: identifier)
                closeConnection(.write)
                
            case [.errorOccurred]:
                tunnel?.sendCloseType(.all, forConnection: identifier)
                abort()
                
            default:
                break
            }
            
        case readStream!:
            testVPNLog(self.TAG + "it's an event of a readStream")
            switch eventCode {
            case [.hasBytesAvailable]:
                if let stream = readStream {
                    while stream.hasBytesAvailable {
                        var readBuffer = [UInt8](repeating: 0, count: 8192)
                        let bytesRead = stream.read(&readBuffer, maxLength: readBuffer.count)
                        
                        if bytesRead < 0 {
                            abort()
                            break
                        }
                        
                        if bytesRead == 0 {
                            testVPNLog(self.TAG + "\(identifier): got EOF, sending close")
                            tunnel?.sendCloseType(.write, forConnection: identifier)
                            closeConnection(.read)
                            break
                        }
                        
                        let readData = NSData(bytes: readBuffer, length: bytesRead)
                        let tmpMutableData = NSMutableData()
                        tmpMutableData.append(readData as Data)
                        testVPNLog(self.TAG + "data read: \(tmpMutableData)")
                        tunnel?.sendData(readData as Data, forConnection: identifier)
                    }
                }
                
            case [.endEncountered]:
                tunnel?.sendCloseType(.write, forConnection: identifier)
                closeConnection(.read)
                
            case [.errorOccurred]:
                if let serverTunnel = tunnel as? ServerTunnel {
                    serverTunnel.sendOpenResultForConnection(connectionIdentifier: identifier, resultCode: .timeout)
                    serverTunnel.sendCloseType(.all, forConnection: identifier)
                    abort()
                }
                
            case [.openCompleted]:
                if let serverTunnel = tunnel as? ServerTunnel {
                    serverTunnel.sendOpenResultForConnection(connectionIdentifier: identifier, resultCode: .success)
                }
                
            default:
                break
            }
        default:
            break
        }
    }
}
