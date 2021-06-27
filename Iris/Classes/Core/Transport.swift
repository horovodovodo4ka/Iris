//
//  NetworkTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Combine

public final class Transport {

    public init(configuration: TransportConfig, executor: Executor) {
        self.configuration = configuration
        self.executor = executor
    }

    public let configuration: TransportConfig
    public let executor: Executor

    public private(set) var middlewares: [Middleware] = []

    public func add(middlware: Middleware) {
        middlewares.append(middlware)
    }

    // MARK: - designated execution, only models
    
    @discardableResult
    public func execute<ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<ResponseType, Error>
    where O: ReadOperation, O.ResponseType == ResponseType {
        executeWithMeta(operation, from: callSite).map { $0.model }.eraseToAnyPublisher()
    }

    @discardableResult
    public func execute<RequestType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<Void, Error>
    where O: WriteOperation, O.RequestType == RequestType {
        executeWithMeta(operation, from: callSite).map { ($0.model) }.eraseToAnyPublisher()
    }

    @discardableResult
    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<ResponseType, Error>
    where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {
        executeWithMeta(operation, from: callSite).map { $0.model }.eraseToAnyPublisher()
    }

    // MARK: - extended execution with headers

    @discardableResult
    public func executeWithMeta<ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<MetaResponse<ResponseType>, Error>
    where O: ReadOperation, O.ResponseType == ResponseType {

        execute(operation: operation,
                data: { nil },
                response: { try self.decode(operation: operation, data: $0) },
                callSite: callSite)
    }

    @discardableResult
    public func executeWithMeta<RequestType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<MetaResponse<Void>, Error>
    where O: WriteOperation, O.RequestType == RequestType {

        execute(operation: operation,
                data: { try self.encode(operation: operation) },
                response: { _ in () },
                callSite: callSite)
    }

    @discardableResult
    public func executeWithMeta<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> AnyPublisher<MetaResponse<ResponseType>, Error>
    where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        execute(operation: operation,
                data: { try self.encode(operation: operation) },
                response: { try self.decode(operation: operation, data: $0) },
                callSite: callSite)
    }

    // MARK: - private

    private func encode<O: WriteOperation>(operation: O) throws -> Data? {
        let encoder = self.configuration.encoder()

        return try encoder.encode(operation.request)
    }

    private func decode<O: ReadOperation>(operation: O, data: Data) throws -> O.ResponseType {
        let decoder = self.configuration.decoder()

        if let path = operation.responseRelativePath {
            guard let traverser = decoder as? ResponseTraversalDecoder else {
                throw TransportError.indirectRequiresTraverser(operation.operationType, type(of: decoder))
            }

            return try traverser.decode(O.ResponseType.self, from: data, at: path)
        } else {

            return try decoder.decode(O.ResponseType.self, from: data)
        }
    }

    private func execute<ResponseType, O: HTTPOperation>(
        operation: O,
        data requestData: @escaping EncodingLambda,
        response: @escaping DecodingLambda<ResponseType>,
        callSite: StackTraceElement) -> AnyPublisher<MetaResponse<ResponseType>, Error> {

        let logger = configuration.printer()

        let uniqueHeaders = Set(middlewares.flatMap { $0.headers }.flatMap { $0(operation: operation).values })
        let headers = uniqueHeaders.map { ($0.key.headerName, $0.value) }

        let context = CallContext(url: operation.url,
                                  method: operation.method,
                                  headers: Dictionary(uniqueKeysWithValues: headers),
                                  printer: logger,
                                  callSite: callSite)

        var onCancel: OperationCancellation = {}

        let barrier = barrier(operation: operation).setFailureType(to: Error.self)

        let request = barrier.flatMap {
            self.executor.execute(context: context, data: requestData)
        }

        let validate = request
            .tryMap { result -> MetaResponse<ResponseType> in
                let headers = Headers(raw: result.response?.allHeaderFields ?? [:])
                let rawResult = RawOperationResult(response: result.response, headers: headers, data: result.data)

                for validator in self.middlewares.flatMap({ $0.validate }) {
                    try validator(operation: operation, result: rawResult)
                }

                let ret = try response(result.data)

                logger.print("Sucсeed!", phase: .decoding(success: true), callSite: callSite)

                return MetaResponse(
                    model: ret,
                    headers: headers
                )
            }

        let success = validate.map { result -> MetaResponse<ResponseType> in
            self.middlewares.flatMap { $0.success }.forEach { $0(operation: operation, result: result.model) }
            return result
        }

        let error = success.catch { e -> Fail<MetaResponse<ResponseType>, Exception> in
            let error = Exception(cause: e, context: callSite)

            logger.print("[Error] " + error.localizedDescription, phase: .decoding(success: false), callSite: callSite)

            return Fail(error: error)
        }

        let recover = error.catch {
            self.recover(operation: operation, error: $0)
                .flatMap {
                    self.execute(operation: operation, data: requestData, response: response, callSite: callSite)
                }
        }

        return recover.eraseToAnyPublisher()
    }

    private func barrier(operation: Operation) -> AnyPublisher<Void, Never> {
        guard middlewares.count > 0 else {
            return Just(()).eraseToAnyPublisher()
        }

        var it = middlewares.flatMap { $0.barrier }.lazy.makeIterator()

        func next() -> AnyPublisher<Void, Never> {
            guard let nextBarrierBlock = it.next() else {
                return Just(()).eraseToAnyPublisher()
            }

            return nextBarrierBlock(operation: operation).flatMap { next() }.eraseToAnyPublisher()
        }

        return next()
    }

    private func recover(operation: Operation, error: Exception) -> AnyPublisher<Void, Error> {
        let cause = error.cause ?? error

        guard middlewares.count > 0 else {
            return Fail(error: cause).eraseToAnyPublisher()
        }

        var it = middlewares.flatMap { $0.recover }.lazy.makeIterator()

        func next() -> AnyPublisher<Void, Error> {
            guard let nextBarrierBlock = it.next() else {
                return Fail(error: cause).eraseToAnyPublisher()
            }

            let block: AnyPublisher<Void, Error>
            do {
                block = try nextBarrierBlock(operation: operation, error: cause)
            } catch {
                block = Fail(error: cause).eraseToAnyPublisher()
            }

            return block
                .catch { _ in next() }
                .eraseToAnyPublisher()
        }

        return next()
    }
}

// MARK: -

public enum TransportError: Swift.Error, LocalizedError {
    case indirectRequiresTraverser(Operation.Type, ResponseDecoder.Type)

    public var errorDescription: String? {
        switch self {
            case .indirectRequiresTraverser(let operation, let decoder):
                return "<\(operation)> requires ResponseTraversalDecoder for parsing. <\(decoder)> is used."
        }
    }
}

typealias EncodingLambda = () throws -> Data?
typealias DecodingLambda<ResponseType> = (Data) throws -> ResponseType

public protocol RequestEncoder {
    func encode<T>(_ value: T) throws -> Data where T: Encodable
}

public protocol ResponseDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable
}

public protocol ResponseTraversalDecoder: ResponseDecoder {
    func decode<T>(_ type: T.Type, from data: Data, at path: String) throws -> T where T: Decodable
}

public struct TransportConfig {
    public let printer: () -> Printer
    public let encoder: () -> RequestEncoder
    public let decoder: () -> ResponseDecoder

    public init(printer: @escaping @autoclosure () -> Printer,
                encoder: @escaping @autoclosure () -> RequestEncoder,
                decoder: @escaping @autoclosure () -> ResponseDecoder) {

        self.printer = printer
        self.encoder = encoder
        self.decoder = decoder
    }
}

public struct MetaResponse<Response> {
    public let model: Response
    public let headers: Headers
}

extension Future where Failure == Error {
    public convenience init(_ attemptToFulfill: @escaping (@escaping Future<Output, Failure>.Promise) throws -> Void) {
        self.init { complete in
            do {
                try attemptToFulfill(complete)
            } catch {
                complete(.failure(error))
            }
        }
    }
}
