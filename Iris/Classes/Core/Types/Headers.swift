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

public struct Headers {
    typealias Element = Dictionary<String, String>.Element

    public let values: [String: String]

    public init(_ headers: [HeaderKey: CustomStringConvertible]) {
        let values = headers.map { ($0.key.headerName, $0.value.description) }
        self.values = Dictionary(uniqueKeysWithValues: values)
    }

    public init(raw headers: [AnyHashable: Any]) {
        let values: [Element] = headers.compactMap {
            guard let key = $0.key as? String, let value = $0.value as? String else { return nil }
            return (key: key.applyKeyRule(), value: value)
        }

        self.values = Dictionary(uniqueKeysWithValues: values)
    }

    public subscript(key: HeaderKey) -> String? {
        values[key.headerName]
    }
}

public extension Headers {
    static let empty = Self([:])
}
