//
//  Headers.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 21.06.2021.
//

import Foundation

private extension String {
    func applyKeyRule() -> String {
        lowercased()
    }
}

//

public struct HeaderKey: Equatable, Hashable {
    public init(name: String) {
        self.headerName = name.applyKeyRule()
        self.name = name
    }

    public let name: String
    let headerName: String

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.headerName == rhs.headerName
    }

    public func hash(into hasher: inout Hasher) {
        headerName.hash(into: &hasher)
    }
}

//

public struct Header {

    public init(key: HeaderKey, value: CustomStringConvertible) {
        self.key = key
        self.value = value.description
    }

    public let key: HeaderKey
    public let value: String
}

extension Header: Hashable {
    public var hashValue: Int { key.hashValue }
    public func hash(into hasher: inout Hasher) {
        key.hash(into: &hasher)
    }
}

extension Header: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key
    }
}

//

public struct Headers {
    typealias Element = Dictionary<String, String>.Element

    public let values: [Header]

    public init(_ headers: [Header]) {
        self.values = headers
    }

    public init(_ headers: Header...) {
        self.init(headers)
    }

    public init(_ headers: [HeaderKey: CustomStringConvertible]) {
        self.values = headers.map { Header(key: HeaderKey(name: $0.key.headerName), value: $0.value.description) }
    }

    public init(raw headers: [AnyHashable: Any]) {
        self.values = headers.compactMap {
            guard let key = $0.key as? String, let value = $0.value as? String else { return nil }
            return Header(key: HeaderKey(name: key.applyKeyRule()), value: value)
        }
    }

    public subscript(key: HeaderKey) -> String? {
        values.first { $0.key == key }?.value
    }
}

public extension Headers {
    static let empty = Self([:])
}
