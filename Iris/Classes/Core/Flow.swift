//
//  Flow.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import PromiseKit

private typealias Pending<T> = (promise: Promise<T>, resolver: Resolver<T>)

private protocol AnyFlow: AnyObject {
    var transport: Transport { get }
    var parent: AnyFlow? { get set }
    var children: [AnyFlow] { get set }

    func cancel()
}

public class Flow<ResponseType>: AnyFlow, Thenable {
    public typealias T = ResponseType

    public func pipe(to: @escaping (Result<ResponseType>) -> Void) {
        host.pipe(to: to)
    }

    public var result: Result<ResponseType>? { host.result }

    private init(host: Promise<ResponseType>,
                 transport: Transport,
                 context: Pending<Void> = Promise<Void>.pending(),
                 cancellationCallback: @escaping () -> () = {}) {

        self.host = race(host.asVoid(), context.promise).map(on: nil) { host.value! }
        self.conext = context
        self.cancellationCallback = cancellationCallback
        self.transport = transport

        self.host
            .done { _ in
                self.finalize()
            }
            .catch(policy: .allErrors) {
                if $0.isCancelled {
                    self.cancelChain()
                }
            }
    }

    fileprivate convenience init(host: Promise<ResponseType>,
                                 transport: Transport,
                                 context: Pending<Void>,
                                 parent: AnyFlow) {
        self.init(host: host, transport: transport, context: context)
        
        parent.children.append(self)
        self.parent = parent
    }

    let transport: Transport
    private let host: Promise<ResponseType>
    private let conext: Pending<Void>
    private let cancellationCallback: () -> ()

    fileprivate var parent: AnyFlow?
    fileprivate var children: [AnyFlow] = []

    func cancel() {
        cancelChain()
    }

    deinit {
        cancelChain()
    }

    func cancelChain() {
        if conext.promise.isPending {
            conext.resolver.reject(PMKError.cancelled)
        }

        children.forEach {
            $0.parent = nil
            $0.cancel()
        }

        cancellationCallback()

        finalize()
        parent?.cancel()
    }

    func finalize() {
        parent?.children.removeAll { $0 === self }
    }
}

public extension Flow {

    convenience init(transport: Transport, promise: Promise<ResponseType>) {
        self.init(host: promise, transport: transport)
    }

    convenience init(transport: Transport, _ factory: (Resolver<ResponseType>) throws -> (OperationCancellation)) {
        var callback: OperationCancellation = {}
        let promise = Promise<ResponseType> { seal in
            callback = try factory(seal)
        }

        self.init(host: promise, transport: transport, cancellationCallback: callback)
    }

    func then<T, C>(_ body: @escaping (ResponseType) throws -> C) -> Flow<T> where C: Thenable, C.T == T {
        let newHost = host.then(body)
        return Flow<T>(host: newHost, transport: transport, context: conext, parent: self)
    }

    func then<T>(_ body: @escaping (ResponseType) throws -> Flow<T>) -> Flow<T> {
        let newHost = host.then { try body($0).host }
        return Flow<T>(host: newHost, transport: transport, context: conext, parent: self)
    }

    func map<T>(_ body: @escaping (ResponseType) throws -> T) -> Flow<T> {
        let newHost = host.map(body)
        return Flow<T>(host: newHost, transport: transport, context: conext, parent: self)
    }

    func get(_ body: @escaping (ResponseType) throws -> Void) -> Flow<ResponseType> {
        let newHost = host.get(body)
        return Flow<ResponseType>(host: newHost, transport: transport, context: conext, parent: self)
    }

    func done(_ body: @escaping (ResponseType) throws -> Void) -> Flow<Void> {
        let newHost = host.done(body)
        return Flow<Void>(host: newHost, transport: transport, context: conext, parent: self)
    }

    func `catch`(_ body: @escaping (Error) -> Void) -> Flow<Void> {
        let newHost = Promise<Void>.pending()

         host.pipe {
            switch $0 {
                case .fulfilled(_): break
                case .rejected(let error):
                    body(error)
            }
            newHost.resolver.fulfill(())
        }

        return Flow<Void>(host: newHost.promise, transport: transport, context: conext, parent: self)
    }

    func recover<C>(_ body: @escaping (Error) throws -> C) -> Flow<ResponseType> where C: Thenable, C.T == ResponseType {
        let newHost = host.recover(body)
        return Flow<ResponseType>(host: newHost, transport: transport, context: conext, parent: self)
    }
}
