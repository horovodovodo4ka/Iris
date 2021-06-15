//
//  SwiftCodable_ext.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

extension JSONEncoder: RequestEncoder {

}

extension JSONDecoder: ResponseDecoder {

}

public let jsonEncoder: RequestEncoder = {
    let e = JSONEncoder()
    e.keyEncodingStrategy = .convertToSnakeCase
    return e
}()

public let jsonDecoder: ResponseDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

