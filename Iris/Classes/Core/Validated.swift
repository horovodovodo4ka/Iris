//
//  ValidatedOperation.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public protocol Validated where Self: Operation {
    var validators: [Validator] { get }
}

public struct Validator {
    let validate: (_ response: HTTPURLResponse, _ data: Data) throws -> Void
}

