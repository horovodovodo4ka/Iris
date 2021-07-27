//
//  Json_ext.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation

extension JSONEncoder: RequestEncoder {
    public func encode<T>(_ value: T) throws -> Model where T : Encodable {
        (data: try encode(value) as Data, meta: .empty)
    }
}

extension JSONDecoder: ResponseDecoder {
    public func decode<T>(_ type: T.Type, from model: Model) throws -> T where T : Decodable {
        try decode(type, from: model.data)
    }
}

extension JSONDecoder: ResponseTraversalDecoder {
    public func decode<T>(_ type: T.Type, from model: Model, at path: String) throws -> T where T : Decodable {
        try decode(JsonPath<T>.self, from: model.data).decode(path: path)
    }
}
