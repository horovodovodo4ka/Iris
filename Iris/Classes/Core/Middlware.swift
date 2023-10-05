//
//  Middlware.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation
import Combine

public struct Middleware {
    public init(barrier: Barrier..., headers: RequestHeaders...,
                validate: Validator..., recover: Recover...,
                success: Success...) {
        self.barrier = barrier
        self.headers = headers
        self.validate = validate
        self.recover = recover
        self.success = success
    }

    let barrier: [Barrier]
    let headers: [RequestHeaders]
    let validate: [Validator]
    let recover: [Recover]
    let success: [Success]
}

// MARK: -

public typealias OperationBarrier = (Operation) async -> Void
public typealias OperationHeaders = (Operation) -> Iris.Headers
public typealias RawOperationResult = (response: HTTPURLResponse?, headers: Iris.Headers, data: Data)
public typealias OperationValidator = (Operation, RawOperationResult) throws -> Void
public typealias OperationRecover = (Operation, Error) async throws -> Void
public typealias OperationSucces = (Operation, Any?) -> Void

public extension Middleware {

    struct Barrier {
        private let barrier: OperationBarrier
        public init(_ barrier: @escaping OperationBarrier) {
            self.barrier = barrier
        }

        public func callAsFunction(operation: Operation) async {
            await barrier(operation)
        }
    }

    struct RequestHeaders {
        private let headers: OperationHeaders
        public init(_ headers: @escaping OperationHeaders) {
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

        public func callAsFunction(operation: Operation, error: Error) async throws {
            try await recover(operation, error)
        }
    }

    struct Success {
        private let success: OperationSucces
        public init(_ success: @escaping OperationSucces) {
            self.success = success
        }

        public func callAsFunction(operation: Operation, result: Any?) {
            success(operation, result)
        }
    }
}

public prefix func <<< (what: @escaping OperationBarrier) -> Middleware.Barrier {
    Middleware.Barrier(what)
}

public prefix func <<< (what: @escaping OperationHeaders) -> Middleware.RequestHeaders {
    Middleware.RequestHeaders(what)
}

public prefix func <<< (what: @escaping OperationValidator) -> Middleware.Validator {
    Middleware.Validator(what)
}

public prefix func <<< (what: @escaping OperationRecover) -> Middleware.Recover {
    Middleware.Recover(what)
}

public prefix func <<< (what: @escaping OperationSucces) -> Middleware.Success {
    Middleware.Success(what)
}

prefix operator <<<
