//
//  NetworkOperationImpl.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

// MARK: - shorthands for most frequently used methods

public protocol GetOperation: ReadOperation {}
public extension GetOperation {
    var method: Get { Get() }
}

public protocol PostOperation: WriteOperation where Self: ReadOperation {}
public extension PostOperation {
    var method: Post { Post() }
}

public protocol PatchOperation: WriteOperation where Self: ReadOperation {}
public extension PatchOperation {
    var method: Patch { Patch() }
}

public protocol DeleteOperation: WriteOperation {}
public extension DeleteOperation {
    var method: Delete { Delete() }
}

// MARK: - statuses to resources mappings
extension Get: RedableResourceHTTPMethod {}
extension Post: CreatableResourceHTTPMethod {}
extension Patch: UpdatableResourceHTTPMethod {}
extension Delete: DeletableResourceHTTPMethod {}

// MARK: - http status default validator

public enum HTTPError: Swift.Error, LocalizedError {
    case clientError(code: Int)
    case serverError(code: Int)
    case unknownResponseCode(code: Int)

    public var errorDescription: String? { "\(self)" }
}

public extension Middleware.Validator {
    static let statusCode = Self {
        let statusCode = $1.response.statusCode
        
        switch statusCode {
            case 100..<300:
                return
            case 400..<500:
                throw HTTPError.clientError(code: statusCode)
            case 500..<600:
                throw HTTPError.serverError(code: statusCode)
            default:
                throw HTTPError.unknownResponseCode(code: statusCode)
        }
    }
}

// MARK: - NOOP printer

public class NoopPrinter: Printer {
    public init() {}

    public func print(_ string: String, phase: Phase, callSite: StackTraceElement) {
        // Do nothing
    }
}

// MARK: - HTTP headers

public extension HeaderKey {
    static func custom(_ name: String) -> Self { Self(name: name) }
    
    static let authorization = Self(name: "Authorization")
    static let contentType = Self(name: "Content-Type")
    static let retryAfter = Self(name: "Retry-After")
    static let contentEncoding = Self(name: "Content-Encoding")
    static let contentLength = Self(name: "Content-Length")
}
