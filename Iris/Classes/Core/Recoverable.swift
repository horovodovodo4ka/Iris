//
//  Recoverable.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public protocol Recoverable where Self: Operation {
    var recoveries: [Recovery<Self>] { get }
}

public struct Recovery<T: Operation> {
    let recover: (T, Error) throws -> Flow<Void>
}
