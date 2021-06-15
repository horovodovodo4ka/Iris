//
//  NetworkOperation.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//


import Foundation
import PromiseKit

public protocol NetworkOperation {
    var headers: [String: String] { get }

    var url: String { get }

    var method: HTTPMethod { get }

    var handler: OperationHandler { get }
}

public protocol ReadOperation: NetworkOperation {
    associatedtype ResponseType: Decodable
}

public protocol WriteOperation: NetworkOperation {
    associatedtype RequestType: Encodable

    var request: RequestType { get }
}

//////////

public struct NetworkOperationValidator {
    let validate: (_ response: HTTPURLResponse, _ data: Data) throws -> Void
}

public struct OperationHandler {
    let validators: [NetworkOperationValidator]
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
