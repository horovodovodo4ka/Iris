//
//  NetworkTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import PromiseKit
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

        if let traversable = operation as? IndirectModelOperation {
            guard let traverser = decoder as? ResponseTraversalDecoder else {
                throw TransportError.indirectRequiresTraverser(type(of: traversable), type(of: decoder))
            }

            return try traverser.decode(O.ResponseType.self, from: data, at: traversable.responseRelativePath)
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

        let headers = middlewares
            .flatMap { $0.headers }
            .map { $0(operation: operation).values }
            .reduce([:]) { result, headers in
                result.merging(headers) { _, new in new }
            }
            .merging(operation.headers.values) { _, new in new }

        let context = CallContext(url: operation.url,
                                  method: operation.method,
                                  headers: headers,
                                  printer: logger,
                                  callSite: callSite)

        var cancellationCallback: OperationCancellation = {}

        let barrier = barrier(operation: operation).setFailureType(to: Error.self)

        let request = barrier.flatMap {
            Future<OperationResult, Error> { complete in
                cancellationCallback = try self.executor.execute(context: context, data: requestData, response: { result in
                    complete(result)
                })
            }
            .handleEvents(receiveCancel: cancellationCallback)
        }

        let validate = request.tryMap { result -> MetaResponse<ResponseType> in
            let headers = Headers(raw: result.response.allHeaderFields)
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

        let error = validate.tryCatch { e -> AnyPublisher<MetaResponse<ResponseType>, Error> in
            let error = Exception(cause: e, context: callSite)

            logger.print("[Error] " + error.localizedDescription, phase: .decoding(success: false), callSite: callSite)

            throw error
        }

        let recover = error.tryCatch { e in
            self.execute(operation: operation, data: requestData, response: response, callSite: callSite)
        }

        return recover.eraseToAnyPublisher()
    }

    private func barrier(operation: Operation) -> AnyPublisher<Void, Never> {
        guard middlewares.count > 0 else {
            return Just(()).eraseToAnyPublisher()
        }

        let lazyPromises = middlewares.flatMap { $0.barrier }.lazy

        var it = lazyPromises.makeIterator()

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

        let lazyPromises = middlewares.flatMap { $0.recover }.lazy

        var it = lazyPromises.makeIterator()

        func next() -> AnyPublisher<Void, Error> {
            guard let nextBarrierBlock = it.next() else {
                return Fail(error: cause).eraseToAnyPublisher()
            }

            return Future<Void, Error> { complete in
                try nextBarrierBlock(operation: operation, error: cause)
            }
            .flatMap { next() }
            .eraseToAnyPublisher()
        }

        return next()
    }

//    private func execute<ResponseType, O: HTTPOperation>(
//        operation: O,
//        data requestData: @escaping EncodingLambda,
//        response: @escaping DecodingLambda<ResponseType>,
//        callSite: StackTraceElement) -> Flow<MetaResponse<ResponseType>> {
//
//        fatalError()
//
        //        let logger = configuration.printer()
        //
        //        let headers = middlewares
        //            .flatMap { $0.headers }
        //            .map { $0(operation: operation).values }
        //            .reduce([:]) { result, headers in
        //                result.merging(headers) { _, new in new }
        //            }
        //            .merging(operation.headers.values) { _, new in new }
        //
        //        let context = CallContext(url: operation.url,
        //                                  method: operation.method,
        //                                  headers: headers,
        //                                  printer: logger,
        //                                  callSite: callSite)
        //
        //        var cancellationCallback: OperationCancellation = {}
        //
        //        let root = Flow<Void>(transport: self, promise: .value(()))
        //
        //        let flow = pipeBarriers(operation: operation, to: root)
        //            .then {
        //                Promise<OperationResult> { seal in
        //                cancellationCallback = try self.executor.execute(context: context, data: requestData) { result in
        //                        switch result {
        //                            case .success(let data):
        //                                seal.fulfill(data)
        //                            case .failure(let error):
        //                                seal.reject(error)
        //                        }
        //                    }
        //                }
        //            }.map { result in
        //                let headers = Headers(raw: result.response.allHeaderFields)
        //                let rawResult = RawOperationResult(response: result.response, headers: headers, data: result.data)
        //
        //                for validator in self.middlewares.flatMap({ $0.validate }) {
        //                    try validator(operation: operation, result: rawResult)
        //                }
        //
        //                let ret = try response(result.data)
        //
        //                logger.print("Sucсeed!", phase: .decoding(success: true), callSite: callSite)
        //
        //                return MetaResponse(
        //                    model: ret,
        //                    headers: headers
        //                )
        //            }.recover { e -> Promise<MetaResponse<ResponseType>> in
        //
        //                let error = Exception(cause: e, context: callSite)
        //
        //                logger.print("[Error] " + error.localizedDescription, phase: .decoding(success: false), callSite: callSite)
        //
        //                throw error
        //            }
        //
        //        let ret = flow
        //            .recover { e -> Flow<MetaResponse<ResponseType>> in
        //                let error = e as! Exception
        //
        //                return self
        //                    .pipeRecovers(operation: operation, error: error, to: flow)
        //                    .then {
        //                        self.execute(operation: operation, data: requestData, response: response, callSite: callSite)
        //                    }
        //            }
        //
        //        ret.cancellationCallback = cancellationCallback
        //
        //        return ret
    }

    // middlewares recover section chaining

    //    private func pipeRecovers<T>(operation: Operation, error: Exception, to: Flow<T>) -> Flow<Void> {
    //        let cause = error.cause ?? error
    //
    //        guard middlewares.count > 0 else {
    //            return Flow(transport: self, promise: Promise(error: error))
    //        }
    //
    //        func safePromise(_ block: Middleware.Recover) -> Promise<Void> {
    //            do {
    //                return try block(operation: operation, error: cause)
    //            } catch {
    //                return Promise(error: cause)
    //            }
    //        }
    //
    //        let lazyPromises = middlewares.flatMap { $0.recover }.lazy.map(safePromise(_:))
    //
    //        var it = lazyPromises.makeIterator()
    //
    //        var tail: Flow<Void>!
    //
    //        func chain(_ promise: Promise<Void>) -> Flow<Void> {
    //            if let f = tail {
    //                tail = f.recover { _ in promise }
    //            } else {
    //                tail = to.map { _ in }.recover { _ in promise }
    //            }
    //            return tail
    //        }
    //
    //        func next() -> Flow<Void> {
    //            // If there is any next recover block, try it
    //            guard let nextRecoverBlock = it.next() else {
    //                return chain(Promise<Void>(error: cause))
    //            }
    //
    //            // If recover block raises error, try next recover block
    //            return chain(nextRecoverBlock).recover { _ in next() }
    //        }
    //
    //        return next().recover { e -> Promise<Void> in
    //            throw Exception(cause: e, context: error.context)
    //        }
    //    }
    //
    //    private func pipeBarriers<T>(operation: Operation, to: Flow<T>) -> Flow<Void> {
    //
    //        guard middlewares.count > 0 else {
    //            return Flow(transport: self, promise: .value(()))
    //        }
    //
    //        func safePromise(_ block: Middleware.Barrier) -> Promise<Void> {
    //            do {
    //                return try block(operation: operation)
    //            } catch {
    //                return Promise(error: error)
    //            }
    //        }
    //
    //        let lazyPromises = middlewares.flatMap { $0.barrier }.lazy.map(safePromise(_:))
    //
    //        var it = lazyPromises.makeIterator()
    //
    //        var tail: Flow<Void>!
    //
    //        func chain(_ promise: Promise<Void>) -> Flow<Void> {
    //            if let f = tail {
    //                tail = f.then { _ in promise }
    //            } else {
    //                tail = to.map { _ in }.then { _ in promise }
    //            }
    //            return tail
    //        }
    //
    //        func next() -> Flow<Void> {
    //            // If there is any next recover block, try it
    //            guard let nextBarrierBlock = it.next() else {
    //                return chain(.value(()))
    //            }
    //
    //            // If recover block raises error, try next recover block
    //            return chain(nextBarrierBlock).then { _ in next() }
    //        }
    //
    //        return next()
    //    }
//}

// MARK: -

public enum TransportError: Swift.Error, LocalizedError {
    case indirectRequiresTraverser(IndirectModelOperation.Type, ResponseDecoder.Type)

    public var errorDescription: String? {
        switch self {
            case .indirectRequiresTraverser(let operation, let decoder):
                return "<\(operation)> requires ResponseTraversalDecoder for parsing. <\(decoder)> is used."
                //            @unknown default:
                //                return "\(self)"
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
