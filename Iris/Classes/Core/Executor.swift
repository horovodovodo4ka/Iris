//
//  Executor.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public typealias OperationCancellation = (() -> Void)
public typealias OperationResult = (response: HTTPURLResponse, data: Data)

public protocol CallContext {
    var printer: NetworkOperationPrinter { get }
    var callSite: StackTraceElement { get }
}

public protocol Executor {
    func execute(operation: NetworkOperation,
                 context: CallContext,
                 data requestData: () throws -> Data?,
                 response: @escaping (Result<OperationResult, Error>) -> Void
    ) throws -> OperationCancellation
}
