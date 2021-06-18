//
//  NetworkOperationImpl.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

/* Example of binding  methods to resources */
extension Get: RedableResourceHTTPMethod {}
extension Post: CreatableResourceHTTPMethod {}
extension Patch: UpdatableResourceHTTPMethod {}
extension Delete: DeletableResourceHTTPMethod {}

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

