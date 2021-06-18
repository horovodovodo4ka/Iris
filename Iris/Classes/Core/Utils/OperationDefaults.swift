//
//  NetworkOperationImpl.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public extension ReadOperation {
    var method: HTTPMethod { .get }
}

public extension WriteOperation {
    var method: HTTPMethod { .post }
}

public extension WriteOperation where Self: ReadOperation {
    var method: HTTPMethod { .post }
}

//MARK: -

public enum HTTPError: Error {
    case clientError(code: Int)
    case serverError(code: Int)
    case unknownResponseCode(code: Int)
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

