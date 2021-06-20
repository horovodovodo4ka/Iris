//
//  Printable.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public protocol Printer: AnyObject {
    func print(_ string: String, phase: Phase, callSite: StackTraceElement)
}

// MARK: -

public enum Phase {
    case request
    case response(success: Bool)
    case decoding(success: Bool)

    public var isError: Bool {
        switch self {
            case let .response(success), let .decoding(success):
                return !success
            case .request:
                return false
        }
    }
}
