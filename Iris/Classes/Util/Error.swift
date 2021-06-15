//
//  Error.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

// TODO move errors wrapping / stringifying to some protocol maybe...
struct NetworkOperationError: Error, CustomStringConvertible {
    let cause: Error

    let description: String

    init(cause: Error, source: Data) {
        self.cause = cause

        switch cause {
            case let e as DecodingError:
                description = "[ResponseDecoding] \(e.description) @ \(String(data: source, encoding: .utf8))"
            default:
                description = "\(cause)"
        }
    }
}

private extension DecodingError {
    var description: String {
        switch self {
            case .typeMismatch(let reason, _):
                return "\(reason)"
            case .valueNotFound(let reason, _):
                return "\(reason)"
            case .keyNotFound(let reason, _):
                return "\(reason)"
            case .dataCorrupted(let context):
                return "\(context)"
            @unknown default:
                return localizedDescription
        }
    }
}
