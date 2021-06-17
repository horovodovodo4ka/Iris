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

    public init(printer: Printer, encoder: RequestEncoder, decoder: ResponseDecoder) {
        self.printer = printer
        self.encoder = encoder
        self.decoder = decoder
    }
}

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
                       data: { try self.configuration.encoder.encode(operation.request) },
                       response: { _ in () },
                       callSite: callSite)
    }

    @discardableResult
    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<ResponseType> where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { try self.configuration.encoder.encode(operation.request) },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    // MARK : - private

    private func execute<ResponseType>(operation: Operation,
                                       data requestData: @escaping () throws -> Data?,
                                       response: @escaping (Data) throws -> ResponseType,
                                       callSite: StackTraceElement) -> Flow<ResponseType> {

        let logger = configuration.printer

        let flow = Flow<OperationResult>(transport: self) { seal in
            try executor
                .execute(operation: operation,
                         context: CallContext(printer: configuration.printer, callSite: callSite),
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
                let rawResult = RawOperationResult(response: result.response, data: result.data)

                for validator in self.middlewares {
                    try validator.validate(operation, rawResult)
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

        return flow
            .recover { e -> Flow<ResponseType> in
                self.pipeRecovers(operation: operation, error: e, to: flow)
                    .then {
                        self.execute(operation: operation, data: requestData, response: response, callSite: callSite)
                    }
            }
    }

    // middlewares recover section chaining

    private func pipeRecovers<T>(operation: Operation, error: Error, to: Flow<T>) -> Flow<Void> {

        guard middlewares.count > 0 else {
            return Flow(transport: self, promise: Promise(error: error))
        }

        func safePromise(_ block: (Operation, Error) throws -> Promise<Void>) -> Promise<Void> {
            do {
                return try block(operation, error)
            } catch {
                return Promise(error: error)
            }
        }

        if middlewares.count == 1, let first = middlewares.first {
            return Flow(transport: self, promise: safePromise(first.recover))
        }

        let lazyPromises = middlewares.map { $0.recover }.lazy.map(safePromise(_:))

        var it = lazyPromises.makeIterator()

        var tail: Flow<Void>!

        func chain(_ promise: Promise<Void>) -> Flow<Void> {
            if let f = tail {
                tail = f.then { promise }
            } else {
                tail = to.then { _ in promise }
            }
            return tail
        }

        func next() -> Flow<Void> {
            // If there is any next recover block, try it
            guard let nextRecoverBlock = it.next() else {
                return chain(Promise<Void>(error: error))
            }

            // If recover block raises error, try next recover block
            return chain(nextRecoverBlock).recover { error in next() }
        }

        return next()
    }
}

