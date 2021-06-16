//
//  NetworkTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import PromiseKit

public protocol ResponseDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable
}

public protocol RequestEncoder {
    func encode<T>(_ value: T) throws -> Data where T : Encodable
}

public struct TransportConfig {
    public let printer: Printer
    public let encoder: RequestEncoder
    public let decoder: ResponseDecoder
    public let middlewares: [Middleware]

    public init(printer: Printer, encoder: RequestEncoder, decoder: ResponseDecoder, middlewares: [Middleware]) {
        self.printer = printer
        self.encoder = encoder
        self.decoder = decoder
        self.middlewares = middlewares
    }
}

public final class Transport {

    public init(configuration: TransportConfig, executor: Executor) {
        self.configuration = configuration
        self.executor = executor
    }

    @discardableResult
    public func execute<ResponseType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<ResponseType> where O: ReadOperation, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { nil },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    @discardableResult
    public func execute<RequestType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<Void> where O: WriteOperation, O.RequestType == RequestType {

        return execute(operation: operation,
                       data: { try configuration.encoder.encode(operation.request) },
                       response: { _ in () },
                       callSite: callSite)
    }

    @discardableResult
    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<ResponseType> where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { try configuration.encoder.encode(operation.request) },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    public let configuration: TransportConfig

    public let executor: Executor

    private func execute<ResponseType>(operation: Operation,
                                       data requestData: () throws -> Data?,
                                       response: @escaping (Data) throws -> ResponseType,
                                       callSite: StackTraceElement) -> Flow<ResponseType> {

        let logger = configuration.printer

        return Flow<OperationResult>(transport: self) { seal in
            try executor
                .execute(operation: operation,
                         context: _CallContext(printer: configuration.printer, callSite: callSite),
                         data: requestData) { result in
                    switch result {
                        case .success(let data):
                            seal.fulfill(data)
                        case .failure(let error):
                            seal.reject(error)
                    }
                }
        }
        .map { result in
            do {
                if let validated = operation as? Validated {
                    for validator in validated.validators {
                        try validator.validate(result.response, result.data)
                    }
                }

                return try response(result.data)
            } catch {
                throw NetworkOperationError(cause: error, source: result.data)
            }
        }
        .recover { e -> Promise<ResponseType> in

            guard let error = e as? NetworkOperationError else { throw e }

            logger.print(error.description, phase: .response(success: false), callSite: callSite)

            throw error
        }
    }
}

public extension Transport {

    @discardableResult
    func execute<ResponseType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<ResponseType>
    where
        O: ReadOperation, O.ResponseType == ResponseType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }

    @discardableResult
    func execute<RequestType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<Void>
    where
        O: WriteOperation, O.RequestType == RequestType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }

    @discardableResult
    func execute<RequestType, ResponseType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<ResponseType>
    where
        O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }
}

// MARK: - private
private struct _CallContext : CallContext {
    let printer: Printer
    let callSite: StackTraceElement
}
