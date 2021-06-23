//
//  Middlware.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation
import PromiseKit

public struct Middleware {
    public init(barrier: Barrier..., headers: RequestHeaders..., validate: Validator..., recover: Recover...) {
        self.barrier = barrier
        self.headers = headers
        self.validate = validate
        self.recover = recover
    }

    let barrier: [Barrier]
    let headers: [RequestHeaders]
    let validate: [Validator]
    let recover: [Recover]
}

// MARK: -

public typealias OperationBarrier = (Operation) -> Promise<Void>
public typealias OparationHeaders = (Operation) -> Iris.Headers
public typealias RawOperationResult = (response: HTTPURLResponse, headers: Headers, data: Data)
public typealias OperationValidator = (Operation, RawOperationResult) throws -> Void
public typealias OperationRecover = (Operation, Error) throws -> Promise<Void>

public extension Middleware {

    struct Barrier {
        private let barrier: OperationBarrier
        public init(_ barrier: @escaping OperationBarrier) {
            self.barrier = barrier
        }

        public func callAsFunction(operation: Operation) -> Promise<Void> {
            barrier(operation)
        }
    }

    struct RequestHeaders {
        private let headers: OparationHeaders
        public init(_ headers: @escaping OparationHeaders) {
            self.headers = headers
        }

        public func callAsFunction(operation: Operation) -> Iris.Headers {
            headers(operation)
        }
    }

    struct Validator {
        private let validate: OperationValidator
        public init(_ validate: @escaping OperationValidator) {
            self.validate = validate
        }

        public func callAsFunction(operation: Operation, result: RawOperationResult) throws {
            try validate(operation, result)
        }
    }

    struct Recover {
        private let recover: OperationRecover
        public init(_ recover: @escaping OperationRecover) {
            self.recover = recover
        }

        public func callAsFunction(operation: Operation, error: Error) throws -> Promise<Void> {
            try recover(operation, error)
        }
    }
}

public prefix func <<< (what: @escaping OperationBarrier) -> Middleware.Barrier {
    Middleware.Barrier(what)
}

public prefix func <<< (what: @escaping OparationHeaders) -> Middleware.RequestHeaders {
    Middleware.RequestHeaders(what)
}

public prefix func <<< (what: @escaping OperationValidator) -> Middleware.Validator {
    Middleware.Validator(what)
}

public prefix func <<< (what: @escaping OperationRecover) -> Middleware.Recover {
    Middleware.Recover(what)
}

prefix operator <<<
