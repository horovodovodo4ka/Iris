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

public extension ReadOperation where Self: WriteOperation {
    var method: HTTPMethod { .post }
}

public enum HTTPError: Error {
    case clientError(code: Int)
    case serverError(code: Int)
    case unknownResponseCode(code: Int)
}

public extension Validator {
    static let success = Validator { response, data in
        switch response.statusCode {
            case 100..<300:
                return
            case 400..<500:
                throw HTTPError.clientError(code: response.statusCode)
            case 500..<600:
                throw HTTPError.serverError(code: response.statusCode)
            default:
                throw HTTPError.unknownResponseCode(code: response.statusCode)
        }
    }
}
