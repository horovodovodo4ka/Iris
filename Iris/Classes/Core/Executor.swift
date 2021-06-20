//
//  Executor.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public typealias OperationCancellation = (() -> Void)
public typealias OperationResult = (response: HTTPURLResponse, data: Data)

public struct CallContext {
    let url: String
    let method: OperationMethod
    let headers: [String: String]
    let printer: Printer
    let callSite: StackTraceElement
}

public protocol Executor {
    func execute(
        context: CallContext,
        data requestData: () throws -> Data?,
        response: @escaping (Swift.Result<OperationResult, Swift.Error>) -> Void
    ) throws -> OperationCancellation
}
