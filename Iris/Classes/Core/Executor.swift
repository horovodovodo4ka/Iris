//
//  Executor.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public typealias OperationCancellation = (() -> Void)
public typealias OperationResult = (response: HTTPURLResponse?, data: Data)

public struct CallContext {
    public let url: String
    public let method: OperationMethod
    public let headers: [String: String]
    public let timeout: TimeInterval?
    public unowned let printer: Printer
    public let callSite: StackTraceElement
}

public protocol Executor {
    func execute(context: CallContext, data requestData: Data?) async throws -> OperationResult
}
