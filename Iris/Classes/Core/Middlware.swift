//
//  Middlware.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation
import PromiseKit

public struct Middleware {
    public init(headers: Headers? = nil, validate: Validator? = nil, recover: Recover? = nil) {
        self.headers = headers
        self.validate = validate
        self.recover = recover
    }

    let headers: Headers?
    let validate: Validator?
    let recover: Recover?
}

// MARK: -

public typealias RawOperationResult = (response: HTTPURLResponse, data: Data)
public typealias OperationValidator = (Operation, RawOperationResult) throws -> Void
public typealias OparationHeaders = (Operation) -> [String: String]
public typealias OperationRecover = (Operation, Error) throws -> Promise<Void>

public struct Headers {
    private let headers: OparationHeaders
    public init(headers: @escaping OparationHeaders) {
        self.headers = headers
    }

    public func callAsFunction(operation: Operation) -> [String: String] {
        headers(operation)
    }
}

public struct Validator {
    private let validate: OperationValidator
    public init(validate: @escaping OperationValidator) {
        self.validate = validate
    }

    public func callAsFunction(operation: Operation, result: RawOperationResult) throws {
        try validate(operation, result)
    }
}

public struct Recover {
    private let recover: OperationRecover
    public init(recover: @escaping OperationRecover) {
        self.recover = recover
    }

    public func callAsFunction(operation: Operation, error: Error) throws -> Promise<Void> {
        try recover(operation, error)
    }
}
