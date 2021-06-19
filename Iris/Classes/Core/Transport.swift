//
//  NetworkTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import PromiseKit

public protocol ResponseDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable
}

public protocol RequestEncoder {
    func encode<T>(_ value: T) throws -> Data where T: Encodable
}

public struct ErrorsVerboser {
    let verboseError: (Error, Data?) -> String?
}

public struct TransportConfig {
    public let printer: () -> Printer
    public let encoder: RequestEncoder
    public let decoder: ResponseDecoder
    public let errorsVerbosers: [ErrorsVerboser]

    public init(printer: @escaping @autoclosure () -> Printer, encoder: RequestEncoder, decoder: ResponseDecoder, errorsVerbosers: [ErrorsVerboser] = []) {
        self.printer = printer
        self.encoder = encoder
        self.decoder = decoder
        self.errorsVerbosers = errorsVerbosers
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
    public func execute<ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> Flow<ResponseType>
    where O: ReadOperation, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { nil },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    @discardableResult
    public func execute<RequestType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> Flow<Void>
    where O: WriteOperation, O.RequestType == RequestType {

        return execute(operation: operation,
                       data: { try self.configuration.encoder.encode(operation.request) },
                       response: { _ in () },
                       callSite: callSite)
    }

    @discardableResult
    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement = .context()) -> Flow<ResponseType>
    where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { try self.configuration.encoder.encode(operation.request) },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    // MARK: - private

    private func execute<ResponseType, O: HTTPOperation>(operation: O,
                                                         data requestData: @escaping () throws -> Data?,
                                                         response: @escaping (Data) throws -> ResponseType,
                                                         callSite: StackTraceElement) -> Flow<ResponseType> {

        let logger = configuration.printer()

        let flow = Flow<OperationResult>(transport: self) { seal in
            try executor
                .execute(operation: operation,
                         context: CallContext(printer: logger, callSite: callSite),
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

                let ret = try response(result.data)

                logger.print("Sucсeed!", phase: .decoding(success: true), callSite: callSite)

                return ret

            } catch {
                throw NetworkOperationError(cause: error, source: result.data)
            }
        }
        .recover { e -> Promise<ResponseType> in
            let error = self.wrap(error: e, callSite: callSite)

            logger.print(error.message ?? "Error", phase: .decoding(success: false), callSite: callSite)

            throw error
        }

        return flow
            .recover { e -> Flow<ResponseType> in
                let error = e as! Exception

                return self
                    .pipeRecovers(operation: operation, error: error, to: flow)
                    .then {
                        self.execute(operation: operation, data: requestData, response: response, callSite: callSite)
                    }
            }
    }

    private func wrap(error: Error, callSite: StackTraceElement) -> Exception {
        let cause: Error
        let data: Data?

        if let error = error as? NetworkOperationError {
            cause = error.cause
            data = error.source
        } else {
            cause = error
            data = nil

        }

        var message: String!
        for verboser in self.configuration.errorsVerbosers {
            if let verbosed = verboser.verboseError(cause, data) {
                message = verbosed
                break
            }
        }

        if message == nil {
            message = cause.localizedDescription
        }

        return Exception(message: message, cause: cause, context: callSite)
    }

    // middlewares recover section chaining

    private func pipeRecovers<T>(operation: Operation, error: Exception, to: Flow<T>) -> Flow<Void> {
        let cause = error.cause ?? error

        guard middlewares.count > 0 else {
            return Flow(transport: self, promise: Promise(error: error))
        }

        func safePromise(_ block: OperationRecover) -> Promise<Void> {
            do {
                return try block(operation, cause)
            } catch {
                return Promise(error: cause)
            }
        }

        let lazyPromises = middlewares.map { $0.recover }.lazy.map(safePromise(_:))

        var it = lazyPromises.makeIterator()

        var tail: Flow<Void>!

        func chain(_ promise: Promise<Void>) -> Flow<Void> {
            if let f = tail {
                tail = f.recover { _ in promise }
            } else {
                tail = to.map { _ in }.recover { _ in promise }
            }
            return tail
        }

        func next() -> Flow<Void> {
            // If there is any next recover block, try it
            guard let nextRecoverBlock = it.next() else {
                return chain(Promise<Void>(error: cause))
            }

            // If recover block raises error, try next recover block
            return chain(nextRecoverBlock).recover { _ in next() }
        }

        return next().recover { e -> Promise<Void> in
            throw self.wrap(error: e, callSite: error.context)
        }
    }
}

// MAKR: - tools
private struct NetworkOperationError: Swift.Error {
    let cause: Swift.Error
    let source: Data

    init(cause: Swift.Error, source: Data) {
        self.cause = cause
        self.source = source
    }
}
