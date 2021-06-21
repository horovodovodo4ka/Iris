//
//  SwiftCodable_ext.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

extension JSONEncoder: RequestEncoder {

}

//

extension JSONDecoder: ResponseDecoder {

}

extension JSONDecoder: ResponseTraversalDecoder {
    public func decode<T>(_ type: T.Type, from data: Data, at path: String) throws -> T where T: Decodable {
        try decode(JsonPath<T>.self, from: data).decode(path: path)
    }
}

//

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
