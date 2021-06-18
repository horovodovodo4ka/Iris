//
//  NetworkOperation.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//


import Foundation
import PromiseKit

public protocol Operation {
    var headers: [String: String] { get }

    var url: String { get }

    var method: HTTPMethod { get }
}

public protocol ReadOperation: Operation {
    associatedtype ResponseType: Decodable
}

public protocol WriteOperation: Operation {
    associatedtype RequestType: Encodable

    var request: RequestType { get }
}

//////////

public enum HTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}
