//
//  SwiftCodable_ext.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

public extension Json {
    static var encoder: RequestEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    static var decoder: ResponseDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}
