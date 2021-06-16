//
//  Middlware.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation
import PromiseKit

public struct RawOperationResult {
    public let response: HTTPURLResponse
    public let data: Data
}

public protocol Middleware {
    func headers(for operation: Operation) -> [String: String]
    func validate(operation: Operation, with result: RawOperationResult) throws
    func recover(operation: Operation, error: Error) throws -> Promise<Void>
}

public extension Middleware {
    func headers(for operation: Operation) -> [String: String] {
        [:]
    }

    func validate(operation: Operation, with result: RawOperationResult) throws {
        //
    }

    func recover(operation: Operation, error: Error) throws -> Promise<Void> {
        return Promise.value(())
    }
}
