//
//  NetworkOperation.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public protocol Operation {
    var url: String { get }
    var timeout: TimeInterval? { get }
}

public extension Operation {
    var timeout: TimeInterval? { nil }
}

public protocol HTTPOperation: Operation {
    associatedtype MethodType: OperationMethod

    var headers: Headers { get }
    
    var method: MethodType { get }
}

public protocol ReadOperation: HTTPOperation {
    associatedtype ResponseType: Decodable
}

public protocol WriteOperation: HTTPOperation {
    associatedtype RequestType: Encodable

    var request: RequestType { get }
}

//

public protocol IndirectResponseOperation where Self: Operation {
    var responseRelativePath: String { get }
}

//

public class OperationMethod {
    fileprivate init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    public var rawValue: String
}

public final class Options: OperationMethod {
    public init() {
        super.init("OPTIONS")
    }
}
public final class Get: OperationMethod {
    public init() {
        super.init("GET")
    }
}
public final class Head: OperationMethod {
    public init() {
        super.init("HEAD")
    }
}
public final class Post: OperationMethod {
    public init() {
        super.init("POST")
    }
}
public final class Put: OperationMethod {
    public init() {
        super.init("PUT")
    }
}
public final class Patch: OperationMethod {
    public init() {
        super.init("PATCH")
    }
}
public final class Delete: OperationMethod {
    public init() {
        super.init("DELETE")
    }
}
public final class Trace: OperationMethod {
    public init() {
        super.init("TRACE")
    }
}
public final class Connect: OperationMethod {
    public init() {
        super.init("CONNECT")
    }
}
