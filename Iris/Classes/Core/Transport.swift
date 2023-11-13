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
    public func execute<ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws -> ResponseType
    where O: ReadOperation, O.ResponseType == ResponseType {
        try await executeWithMeta(operation, from: callSite).model
    }

    @discardableResult
    public func execute<RequestType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws
    where O: WriteOperation, O.RequestType == RequestType {
        try await executeWithMeta(operation, from: callSite)
    }

    @discardableResult
    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws -> ResponseType
    where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {
        try await executeWithMeta(operation, from: callSite).model
    }

    // MARK: - extended execution with headers

    @discardableResult
    public func executeWithMeta<ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws -> MetaResponse<ResponseType>
    where O: ReadOperation, O.ResponseType == ResponseType {

        try await execute(operation: operation,
                data: { nil },
                response: { [unowned self] in try self.decode(operation: operation, model: $0) },
                callSite: callSite)
    }

    @discardableResult
    public func executeWithMeta<RequestType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws -> MetaResponse<Void>
    where O: WriteOperation, O.RequestType == RequestType {

        try await execute(operation: operation,
                data: { [unowned self] in try self.encode(operation: operation) },
                response: { _ in () },
                callSite: callSite)
    }

    @discardableResult
    public func executeWithMeta<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) async throws -> MetaResponse<ResponseType>
    where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        try await execute(operation: operation,
                data: { [unowned self] in try self.encode(operation: operation) },
                response: { [unowned self] in try self.decode(operation: operation, model: $0) },
                callSite: callSite)
    }

    // MARK: - private

    private func encode<O: WriteOperation>(operation: O) throws -> Model {
        let encoder = self.configuration.encoder()

        return try encoder.encode(operation.request)
    }

    private func decode<O: ReadOperation>(operation: O, model: Model) throws -> O.ResponseType {
        let decoder = self.configuration.decoder()

        if let traverable = operation as? IndirectResponseOperation {
            guard let traverser = decoder as? ResponseTraversalDecoder else {
                throw TransportError.indirectRequiresTraverser(type(of: operation), type(of: decoder))
            }

            return try traverser.decode(O.ResponseType.self, from: model, at: traverable.responseRelativePath)
        } else {

            return try decoder.decode(O.ResponseType.self, from: model)
        }
    }

    private func execute<ResponseType, O: HTTPOperation>(
        operation: O,
        data requestData: @escaping EncodingLambda,
        response: @escaping DecodingLambda<ResponseType>,
        callSite: StackTraceElement) async throws -> MetaResponse<ResponseType> {

            let logger = configuration.printer()

            do {
                try await barrier(operation: operation)

                let rawResult = try await runRequest(operation: operation,
                                                     logger: logger,
                                                     callSite: callSite,
                                                     requestData)

                try validator(operation: operation, result: rawResult)

                let ret = try response((data: rawResult.data, meta: rawResult.headers))

                logger.print("Sucсeed!", phase: .decoding(success: true), callSite: callSite)

                return MetaResponse(model: ret, headers: rawResult.headers)

            } catch {
                let error = Exception(cause: error, context: callSite)

                logger.print("[Error] " + error.localizedDescription, phase: .decoding(success: false), callSite: callSite)

                do {
                    try await recover(operation: operation, error: error)
                    return try await execute(operation: operation, data: requestData, response: response, callSite: callSite)
                } catch {
                    if error is Exception { throw error }
                    throw Exception(cause: error, context: callSite)
                }
            }
    }

    private func runRequest<O: HTTPOperation>(operation: O,
                                               logger: Printer,
                                               callSite: StackTraceElement,
                                               _ requestData: EncodingLambda) async throws -> RawOperationResult {
        let content = try requestData()
        let modelHeaders = content?.meta?.values ?? []
        let operationHeaders = operation.headers.values
        let middlewareHeaders = middlewares
            .flatMap { $0.headers }
            .flatMap { $0(operation: operation).values }
            .reversed()

        let uniqueHeaders = Set(modelHeaders + operationHeaders + middlewareHeaders)

        let headers = uniqueHeaders.map { ($0.key.name, $0.value) }

        let context = CallContext(url: operation.url,
                                  method: operation.method,
                                  headers: Dictionary(uniqueKeysWithValues: headers),
                                  timeout: operation.timeout,
                                  printer: logger,
                                  callSite: callSite)

        let operationResult = try await executor.execute(context: context, data: content?.data)

        let responseHeaders = Headers(raw: operationResult.response?.allHeaderFields ?? [:])
        let rawResult = RawOperationResult(response: operationResult.response,
                                           headers: responseHeaders,
                                           data: operationResult.data)

        return rawResult
    }

    private func barrier(operation: Operation) async {
        for barrier in middlewares.flatMap { $0.barrier } {
            await barrier(operation: operation)
        }
    }

    private func recover(operation: Operation, error: Exception) async throws {
        let cause = error.cause ?? error

        for recover in middlewares.flatMap { $0.recover } {
            do {
                try await recover(operation: operation, error: cause)
                return
            } catch { }
        }

        throw cause
    }

    private func validator<O: HTTPOperation>(operation: O, result rawResult: RawOperationResult) throws {
        for validator in middlewares.flatMap({ $0.validate }) {
            try validator(operation: operation, result: rawResult)
        }
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

public typealias Model = (data: Data, meta: Headers?)
typealias EncodingLambda = () throws -> Model?
typealias DecodingLambda<ResponseType> = (Model) throws -> ResponseType

public protocol RequestEncoder {
    func encode<T>(_ value: T) throws -> Model where T: Encodable
}

public protocol ResponseDecoder {
    func decode<T>(_ type: T.Type, from model: Model) throws -> T where T: Decodable
}

public protocol ResponseTraversalDecoder: ResponseDecoder {
    func decode<T>(_ type: T.Type, from model: Model, at path: String) throws -> T where T: Decodable
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
