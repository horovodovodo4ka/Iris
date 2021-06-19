//
//  NetworkOperationImpl.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

// MARK: - shorthands for most frequently used methods

public protocol GetOperation: ReadOperation {}
public extension GetOperation {
    var method: Get { Get() }
}

public protocol PostOperation: WriteOperation where Self: ReadOperation {}
public extension PostOperation {
    var method: Post { Post() }
}

public protocol PatchOperation: WriteOperation where Self: ReadOperation {}
public extension PatchOperation {
    var method: Patch { Patch() }
}

public protocol DeleteOperation: WriteOperation {}
public extension DeleteOperation {
    var method: Delete { Delete() }
}

// MARK: - statuses to resources mappings
extension Get: RedableResourceHTTPMethod {}
extension Post: CreatableResourceHTTPMethod {}
extension Patch: UpdatableResourceHTTPMethod {}
extension Delete: DeletableResourceHTTPMethod {}

// MARK: - http status default validator

public enum HTTPError: Swift.Error, LocalizedError {
    case clientError(code: Int)
    case serverError(code: Int)
    case unknownResponseCode(code: Int)

    public var errorDescription: String? { "\(self)" }
}

public let statusCodeValidator: OperationValidator = {
    let statusCode = $1.response.statusCode

    switch statusCode {
        case 100..<300:
            return
        case 400..<500:
            throw HTTPError.clientError(code: statusCode)
        case 500..<600:
            throw HTTPError.serverError(code: statusCode)
        default:
            throw HTTPError.unknownResponseCode(code: statusCode)
    }
}

// MARK: - decoding error verboser

public extension ErrorsVerboser {
    static let decoding = ErrorsVerboser { e, _ in
        (e as? DecodingError)?.description
    }
}

private extension DecodingError {
    var description: String {
        switch self {
            case .typeMismatch(let reason, _):
                return "[Decoding error] \(reason)"
            case .valueNotFound(let reason, _):
                return "[Decoding error] \(reason)"
            case .keyNotFound(let reason, _):
                return "[Decoding error] \(reason)"
            case .dataCorrupted(let context):
                return "[Decoding error] \(context.debugDescription)"
            @unknown default:
                return localizedDescription
        }
    }
}
//
//
// public extension ErrorsVerboser {
//    public static let nsError = ErrorsVerboser { e, data in
//        (e as? NSError)?.description
//    }
// }
