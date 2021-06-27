//
//  JsonPath.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation

private struct JSONCodingKeys: CodingKey {
    let stringValue: String

    init?(stringValue: String) {
        self.intValue = nil
        self.stringValue = stringValue
    }

    let intValue: Int?

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

private enum JsonPathToken {
    case property(String)
    case index(Int)

    init(_ string: String) {
        if string.last! == "]" {
            self = .index(Int(String(string.dropLast()))!)
        } else {
            self = .property(string)
        }
    }

    fileprivate var key: JSONCodingKeys {
        switch self {
            case .index(let index):
                return JSONCodingKeys(intValue: index)!
            case .property(let prop):
                return JSONCodingKeys(stringValue: prop)!
        }
    }
}

fileprivate extension String {
    func jsonTokens() -> [JsonPathToken] {
        split { $0 == "." || $0 == "["}
            .filter { !$0.isEmpty }
            .map { JsonPathToken(String($0)) }
    }
}

public class JsonPath<T: Decodable>: Decodable {

    private let decoder: Decoder

    public required init(from decoder: Decoder) throws {
        self.decoder = decoder
    }

    private func decode(_ tokens: [JsonPathToken]) throws -> T {
        let token = tokens.first!
        let tokens = Array(tokens.dropFirst())

        switch token {
            case .index:
                return try decode(index: token, tokens: tokens, container: try decoder.unkeyedContainer())
            case .property:
                return try decode(property: token, tokens: tokens, container: try decoder.container(keyedBy: JSONCodingKeys.self))
        }
    }

    private func decode(index: JsonPathToken, tokens: [JsonPathToken], container: UnkeyedDecodingContainer) throws -> T {
        var container = container

        let idx = index.key.intValue!

        if !tokens.isEmpty {
            let token = tokens.first!
            let tokens = Array(tokens.dropFirst())

            switch token {
                case .index:
                    try (0..<idx).forEach { _ in _ = try container.nestedUnkeyedContainer() }
                    return try decode(index: token, tokens: tokens, container: container.nestedUnkeyedContainer())
                case .property:
                    try (0..<idx).forEach { _ in _ = try container.nestedContainer(keyedBy: JSONCodingKeys.self) }
                    return try decode(property: token, tokens: tokens, container: container.nestedContainer(keyedBy: JSONCodingKeys.self))
            }
        } else {
            try (0..<idx).forEach { _ in _ = try container.decode(T.self) }
            return try container.decode(T.self)
        }
    }

    private func decode(property: JsonPathToken, tokens: [JsonPathToken], container: KeyedDecodingContainer<JSONCodingKeys>) throws -> T {
        if !tokens.isEmpty {
            let token = tokens.first!
            let tokens = Array(tokens.dropFirst())

            switch token {
                case .index:
                    return try decode(index: token, tokens: tokens, container: container.nestedUnkeyedContainer(forKey: property.key))
                case .property:
                    return try decode(property: token, tokens: tokens, container: container.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: property.key))
            }
        } else {
            return try container.decode(T.self, forKey: property.key)
        }
    }

    // public

    public func decode(path: String?) throws -> T {
        guard let tokens = path?.jsonTokens(), !tokens.isEmpty else {
            return try decoder.singleValueContainer().decode(T.self)
        }
        return try decode(tokens)
    }
}

public extension ReadOperation {
    var responseRelativePath: String? { nil }
}
