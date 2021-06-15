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
    public let printer: NetworkOperationPrinter
    public let encoder: RequestEncoder
    public let decoder: ResponseDecoder

    public init(printer: NetworkOperationPrinter, encoder: RequestEncoder, decoder: ResponseDecoder) {
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

    public func execute<ResponseType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<ResponseType> where O: ReadOperation, O.ResponseType == ResponseType {

        return execute(operation: operation,
                       data: { nil },
                       response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                       callSite: callSite)
    }

    public func execute<RequestType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<Void> where O: WriteOperation, O.RequestType == RequestType {

        return execute(operation: operation,
                data: { try configuration.encoder.encode(operation.request) },
                response: { _ in () },
                callSite: callSite)
    }


    public func execute<RequestType, ResponseType, O>(_ operation: O, from callSite: StackTraceElement) -> Flow<ResponseType> where O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        return execute(operation: operation,
                data: { try configuration.encoder.encode(operation.request) },
                response: { try self.configuration.decoder.decode(ResponseType.self, from: $0) },
                callSite: callSite)
    }

    public let configuration: TransportConfig

    public let executor: Executor

    private func execute<ResponseType>(operation: NetworkOperation,
                                       data requestData: () throws -> Data?,
                                       response: @escaping (Data) throws -> ResponseType,
                                       callSite: StackTraceElement) -> Flow<ResponseType> {

        let logger = configuration.printer

        let race = Promise<Void>.pending()

        var cancellation: OperationCancellation!

        return Promise<OperationResult> { seal in
            cancellation = try executor
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
        .asFlow(race, onCancel: cancellation)
        .map { result in
            do {
                for validator in operation.handler.validators {
                    try validator.validate(result.response, result.data)
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
        .asFlow(race, onCancel: cancellation)
    }
}

public extension Transport {
    func execute<ResponseType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<ResponseType>
    where
        O: ReadOperation, O.ResponseType == ResponseType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }

    func execute<RequestType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<Void>
    where
        O: WriteOperation, O.RequestType == RequestType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }

    func execute<RequestType, ResponseType, O>(_ operation: O, file: StaticString = #file, method: StaticString = #function, line: UInt = #line, column: UInt = #column) -> Flow<ResponseType>
    where
        O: ReadOperation & WriteOperation, O.RequestType == RequestType, O.ResponseType == ResponseType {

        let callSite = StackTraceElement(filename: file, method: method, line: line, column: column)

        return execute(operation, from: callSite)
    }
}

// MARK: - private
private struct _CallContext : CallContext {
    let printer: NetworkOperationPrinter
    let callSite: StackTraceElement
}

private typealias Pending<T> = (promise: Promise<T>, resolver: Resolver<T>)

private final class FlowImpl<ResponseType> : Flow<ResponseType> {
    private let cancellation: Pending<Void>
    private let wrapped: Promise<ResponseType>
    private let promise: Promise<ResponseType>

    private let onCancel: OperationCancellation

    init(promise: Promise<ResponseType>, cancellation: Pending<Void>, onCancel: @escaping OperationCancellation) {
        self.wrapped = promise
        self.promise = promise //race(promise.asVoid(), cancellation.promise).map { $0 as! ResponseType }
        self.cancellation = cancellation
        self.onCancel = onCancel
    }


    override func pipe(to: @escaping (Result<ResponseType>) -> Void) {
        promise.pipe(to: to)
    }

    override var result: Result<ResponseType>? {
        promise.result
    }

    public override func cancel() {
        if promise.isPending {
            cancellation.resolver.reject(PMKError.cancelled)
            onCancel()
        }
    }
}

private extension Promise {
    func asFlow(_ cancellation: Pending<Void>, onCancel: @escaping OperationCancellation) -> Flow<T> {
        FlowImpl(promise: self, cancellation: cancellation, onCancel: onCancel)
    }
}
