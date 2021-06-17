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
    let printer: Printer
    let callSite: StackTraceElement
}

public protocol Executor {
    func execute(operation: Operation,
                 context: CallContext,
                 data requestData: () throws -> Data?,
                 response: @escaping (Result<OperationResult, Error>) -> Void
    ) throws -> OperationCancellation
}
