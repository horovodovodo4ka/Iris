//
//  Json_ext.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation

extension JSONEncoder: RequestEncoder {

}

extension JSONDecoder: ResponseDecoder {

}

extension JSONDecoder: ResponseTraversalDecoder {
    public func decode<T>(_ type: T.Type, from data: Data, at path: String) throws -> T where T: Decodable {
        try decode(JsonPath<T>.self, from: data).decode(path: path)
    }
}
