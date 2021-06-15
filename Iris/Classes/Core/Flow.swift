//
//  Flow.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import PromiseKit

/// Abstract class
public class Flow<ResponseType>: Thenable {
    public typealias T = ResponseType

    public func pipe(to: @escaping (Result<ResponseType>) -> Void) {
        fatalError("It's abstract, not implemented")
    }

    public var result: Result<ResponseType>? { nil }

    func cancel() {
        fatalError("It's abstract, not implemented")
    }
}
