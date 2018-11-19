//
//  SOCKS5Enums.swift
//  testVPNServices
//
//  Created by Joe Liu on 2018/11/4.
//  Copyright © 2018年 NUDT. All rights reserved.
//
//  Here I enumerate some constants for socks5 protocol.
//  Todo:
//  Add struct for request and response message in data form
//

import Foundation

/// socks5 protocol version: by default is version 5
public let SOCKS5_VER = 0x05 as UInt8

/// socks5 protocol reserved byte
public let SOCKS5_RSV = 0x00 as UInt8

/// possible authentication methods for socks5 protocol
public enum SOCKS5_AUTH_METHOD: UInt8 {
    case NO_AUTH = 0x00 // no authentication required
    case GSSAPI = 0x01  // gssapi
    case UNAME_PASSWD = 0x02    // username & password
    // 0x03 - 0x7f for IANA ASSIGNED, but not supported by my application
    // 0x80 - 0xfe for RESERVED FOR PRIVATE METHODS, not supported here
    case NO_ACCEPTABLE_METHOD = 0xff    // client did not offer a supported auth method supported by server to server
}

/// possible command for client's request to socks5 server
public enum SOCKS5_CMD: UInt8 {
    case CONNECT = 0x01
    case BIND = 0x02
    case UDP_ASSOCIATE = 0x03
}

/// address types that socks5 accepts
public enum SOCKS5_ATYP: UInt8 {
    case IPV4 = 0x01
    case DOMAINNAME = 0x03
    case IPV6 = 0x04
}

/// possible reply for client's request to socks5 server
public enum SOCKS5_REP: UInt8 {
    case SUCCEEDED = 0x00   // request succeeded
    case SERVER_FAILURE = 0x01  // general SOCKS server failure
    case CONNECTION_NOT_ALLOWED = 0x02  // connection not allowed by ruleset
    case NETWORK_UNREACHABLE = 0x03 // network unreachable
    case HOST_UNREACHABLE = 0x04    // host unreachable
    case CONNECTION_REFUSED = 0x05  // connection refused
    case TTL_EXPIRED = 0x06 // TTL expired
    case COMMAND_NOT_SUPPORTED = 0x07   // command not supported
    case ADDRESS_NOT_SUPPORTED = 0x08   // address type not supported
    case TO_FF_UNASSIGNED = 0x09    // to 0xff unassigned
}
