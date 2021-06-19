//
//  Exception.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 19.06.2021.
//

import Foundation

open class Exception: Error {

    public let message: String?
    public let cause: Swift.Error?
    public let context: StackTraceElement

    public init(message: String? = nil, cause: Swift.Error? = nil, context: StackTraceElement = .context()) {
        self.message = message
        self.cause = cause
        self.context = context
    }

    open var localizedDescription: String { message ?? String(describing: Self.self) }
}
