//
//  Middlware.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation
import PromiseKit

public typealias OperationValidator = (Operation, RawOperationResult) throws -> Void
public typealias OparationHeaders = (Operation) -> [String : String]
public typealias OperationRecover = (Operation, Error) throws -> Promise<Void>

public struct RawOperationResult {
    public let response: HTTPURLResponse
    public let data: Data
}

public struct Middleware {
    public init(headers: @escaping OparationHeaders = { _ in [:] },
                validate: @escaping OperationValidator = { _, _ in },
                recover: @escaping OperationRecover = { _, error in .init(error: error) }) {
        self.headers = headers
        self.validate = validate
        self.recover = recover
    }

    let headers: (Operation) -> [String: String]
    let validate: (Operation, RawOperationResult) throws -> Void
    let recover: (Operation, Error) throws -> Promise<Void>
}
