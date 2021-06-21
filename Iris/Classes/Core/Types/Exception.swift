//
//  Exception.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 19.06.2021.
//

import Foundation

open class Exception: Error, CustomDebugStringConvertible, LocalizedError {

    public let message: String?
    public let cause: Swift.Error?
    public let context: StackTraceElement

    public init(message: String? = nil, cause: Swift.Error? = nil, context: StackTraceElement = .context()) {
        self.message = message
        self.cause = cause
        self.context = context
    }

    open var errorDescription: String? {
        message ?? cause?.localizedDescription ?? String(describing: Self.self)
    }

    open var debugDescription: String {
        var nested = "nil"
        if let cause = cause {
            let offset = "\n    "
            nested = offset + String(describing: cause).replacingOccurrences(of: "\n", with: offset)
        }

        var messageString = "nil"
        if let message = message {
            var escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
            escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
            messageString = "\"\(escaped)\""
        }

        return """
                ▿ \(String(describing: Self.self))
                  - message: \(messageString)
                  \(cause == nil ? "-" : "▿") cause: \(nested)
                """
    }
}
