//
//  NetworkOperationImpl.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public extension NetworkOperation {
    var handler: OperationHandler {
        OperationHandler(validators: [])
    }
}

public extension ReadOperation {
    var method: HTTPMethod { .get }
}

public extension WriteOperation {
    var method: HTTPMethod { .post }
}

public extension ReadOperation where Self: WriteOperation {
    var method: HTTPMethod { .post }
}
