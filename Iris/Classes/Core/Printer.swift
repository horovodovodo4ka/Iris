//
//  Printable.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public protocol Printer {
    func print(_ string: String, phase: Phase, callSite: StackTraceElement)
}

public enum Phase {
    case request
    case response(success: Bool)

    public var isError: Bool {
        switch self {
            case let .response(success):
                return !success
            case .request:
                return false
        }
    }
}