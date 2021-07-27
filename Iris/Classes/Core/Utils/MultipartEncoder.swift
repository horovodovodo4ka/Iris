//
//  MultipartEncoder.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.07.2021.
//

import Foundation

public protocol MultipartFormData {
    var contentType: String { get }
    var contentLength: UInt64 { get }

    func append(_ data: Data, withName name: String, fileName: String?, mimeType: String?)
    func encode() throws -> Data
}

public struct File: Encodable {
    public init(data: Data, fileName: String, mimeType: String) {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }

    public let data: Data
    public let fileName: String
    public let mimeType: String
}


public final class MultipartEncoder: RequestEncoder {
    private let multipart: () -> MultipartFormData

    public init(multipartData: @escaping @autoclosure () -> MultipartFormData) {
        multipart = multipartData
    }

    public func encode<T>(_ value: T) throws -> Model where T : Encodable {
        let mp = multipart()
        try value.encode(to: MPEncoding(to: .init(mp)))
        return (data: try mp.encode(),
                meta: Headers(raw:[
                    "Content-Type": mp.contentType,
                    "Content-Length": mp.contentLength
                ])
        )
    }
}

private final class Mediator {
    init(_ mp: MultipartFormData) {
        self.mp = mp
    }

    let mp: MultipartFormData

    func encode(key codingKey: [CodingKey], value: Data) {
        mp.append(value, withName: stringKey(from: codingKey), fileName: nil, mimeType: nil)
    }

    func encode(key codingKey: [CodingKey], value: File) {
        mp.append(value.data, withName: stringKey(from: codingKey), fileName: value.fileName, mimeType: value.mimeType)
    }

    private func stringKey(from codingKey: [CodingKey]) -> String {
        var reversed = Array(codingKey.reversed())
            .map { $0.stringValue }
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }

        let firstToken = reversed.popLast()
        let subkeys = Array(reversed.reversed()).map { "[\($0)]"}

        return ([firstToken] + subkeys).compactMap { $0 }.joined()
    }
}

private struct MPEncoding: Encoder {

    fileprivate let data: Mediator

    init(to encodedData: Mediator) {
        self.data = encodedData
    }

    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        var container = MPKeyedEncoding<Key>(to: data)
        container.codingPath = codingPath
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        var container = MPUnkeyedEncoding(to: data)
        container.codingPath = codingPath
        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        var container = MPSingleValueEncoding(to: data)
        container.codingPath = codingPath
        return container
    }
}

private struct MPKeyedEncoding<Key: CodingKey>: KeyedEncodingContainerProtocol {
    fileprivate let data: Mediator

    init(to encodedData: Mediator) {
        self.data = encodedData
    }

    var codingPath: [CodingKey] = []

    mutating func encodeNil(forKey key: Key) throws {
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: value.data(using: .utf8)!)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Data, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: value)
    }

    mutating func encode(_ value: File, forKey key: Key) throws {
        data.encode(key: codingPath + [key], value: value)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        switch value {
            case let data as Data:
                try encode(data, forKey: key)
                return
            case let file as File:
                try encode(file, forKey: key)
                return
            default:
                break
        }

        var stringsEncoding = MPEncoding(to: data)
        stringsEncoding.codingPath = codingPath + [key]
        try value.encode(to: stringsEncoding)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        var container = MPKeyedEncoding<NestedKey>(to: data)
        container.codingPath = codingPath + [key]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        var container = MPUnkeyedEncoding(to: data)
        container.codingPath = codingPath + [key]
        return container
    }

    mutating func superEncoder() -> Encoder {
        let superKey = Key(stringValue: "super")!
        return superEncoder(forKey: superKey)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        var stringsEncoding = MPEncoding(to: data)
        stringsEncoding.codingPath = codingPath + [key]
        return stringsEncoding
    }
}

private struct MPUnkeyedEncoding: UnkeyedEncodingContainer {
    fileprivate var data: Mediator

    init(to encodedData: Mediator) {
        self.data = encodedData
    }

    var codingPath: [CodingKey] = []

    private(set) var count: Int = 0

    private mutating func nextIndexedKey() -> CodingKey {
        let nextCodingKey = IndexedCodingKey(intValue: count)!
        count += 1
        return nextCodingKey
    }

    private struct IndexedCodingKey: CodingKey {
        let intValue: Int?
        let stringValue: String

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }

        init?(stringValue: String) {
            return nil
        }
    }

    mutating func encodeNil() throws {
    }

    mutating func encode(_ value: Bool) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: String) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: value.data(using: .utf8)!)
    }

    mutating func encode(_ value: Double) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Float) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int8) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int16) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int32) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int64) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt8) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt16) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt32) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt64) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Data) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: value)
    }

    mutating func encode(_ value: File) throws {
        data.encode(key: codingPath + [nextIndexedKey()], value: value)
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        switch value {
            case let data as Data:
                try encode(data)
                return
            case let file as File:
                try encode(file)
                return
            default:
                break
        }

        var stringsEncoding = MPEncoding(to: data)
        stringsEncoding.codingPath = codingPath + [nextIndexedKey()]
        try value.encode(to: stringsEncoding)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        var container = MPKeyedEncoding<NestedKey>(to: data)
        container.codingPath = codingPath + [nextIndexedKey()]
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        var container = MPUnkeyedEncoding(to: data)
        container.codingPath = codingPath + [nextIndexedKey()]
        return container
    }

    mutating func superEncoder() -> Encoder {
        var stringsEncoding = MPEncoding(to: data)
        stringsEncoding.codingPath.append(nextIndexedKey())
        return stringsEncoding
    }
}

private struct MPSingleValueEncoding: SingleValueEncodingContainer {
    fileprivate var data: Mediator

    init(to encodedData: Mediator) {
        self.data = encodedData
    }

    var codingPath: [CodingKey] = []

    mutating func encodeNil() throws {
    }

    mutating func encode(_ value: Bool) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: String) throws {
        data.encode(key: codingPath, value: value.data(using: .utf8)!)
    }

    mutating func encode(_ value: Double) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Float) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int8) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int16) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int32) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Int64) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt8) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt16) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt32) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: UInt64) throws {
        data.encode(key: codingPath, value: String(value).data(using: .utf8)!)
    }

    mutating func encode(_ value: Data) throws {
        data.encode(key: codingPath, value: value)
    }

    mutating func encode(_ value: File) throws {
        data.encode(key: codingPath, value: value)
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        switch value {
            case let data as Data:
                try encode(data)
                return
            case let file as File:
                try encode(file)
                return
            default:
                break
        }

        var stringsEncoding = MPEncoding(to: data)
        stringsEncoding.codingPath = codingPath
        try value.encode(to: stringsEncoding)
    }
}
