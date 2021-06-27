//
//  File.swift
//  Iris
//
//  Created by Anna Sidorova on 17.06.2021.
//

import Foundation
import Combine

public protocol Resource {
    var transport: Transport { get }

    var url: String { get }
}

public protocol ResourceOperation {
    var url: String { get set }
}

public protocol RedableResourceHTTPMethod { }

public protocol CreatableResourceHTTPMethod { }

public protocol UpdatableResourceHTTPMethod { }

public protocol DeletableResourceHTTPMethod { }

//

public enum ResourceId<Id: CustomStringConvertible> {
    case this
    case element(Id)
}

public protocol Readable: Resource {
    associatedtype ModelId: CustomStringConvertible
    associatedtype ModelType
    associatedtype ReadOperationType: ReadOperation & ResourceOperation
    where
        ReadOperationType.ResponseType == ModelType,
        ReadOperationType.MethodType: RedableResourceHTTPMethod

    func readOperation(_ resourceId: ResourceId<ModelId>) -> ReadOperationType
}

public extension Readable {
    func read(entityWithId id: ResourceId<ModelId> = .this, _ callSite: StackTraceElement = .context()) -> AnyPublisher<ModelType, Error> {
        let op = ResourceReadOpWrapper(wrapped: readOperation(id), url: url)
        return transport.execute(op, from: callSite)
    }
}

//

public protocol Listable: Resource {
    associatedtype ModelType
    associatedtype ListOperationType: ReadOperation where
        ListOperationType.ResponseType == [ModelType],
        ListOperationType.MethodType: RedableResourceHTTPMethod

    func listOperation() -> ListOperationType
}

public extension Listable {
    func list(_ callSite: StackTraceElement = .context()) -> AnyPublisher<[ModelType], Error> {
        let op = ResourceReadOpWrapper(wrapped: listOperation(), url: url)
        return transport.execute(op, from: callSite)
    }
}

//

public protocol Creatable: Resource {
    associatedtype ModelType
    associatedtype NewModelType // suppose that this is incomplete Model
    associatedtype CreateOperationType: ReadOperation & WriteOperation where
        CreateOperationType.ResponseType == ModelType,
        CreateOperationType.RequestType == NewModelType,
        CreateOperationType.MethodType: CreatableResourceHTTPMethod

    func createOperation(_ model: NewModelType) -> CreateOperationType
}

public extension Creatable {
    func create(entity model: NewModelType, _ callSite: StackTraceElement = .context()) -> AnyPublisher<ModelType, Error> {
        let op = ResourceRWOpWrapper(wrapped: createOperation(model), url: url)
        return transport.execute(op, from: callSite)
    }
}

//

public protocol Updateable: Resource {
    associatedtype ModelType
    associatedtype UpdateOperationType: ReadOperation & WriteOperation where
        UpdateOperationType.ResponseType == ModelType,
        UpdateOperationType.RequestType == ModelType,
        UpdateOperationType.MethodType: CreatableResourceHTTPMethod

    func updateOperation(_ model: ModelType) -> UpdateOperationType
}

public extension Updateable {
    func update(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> AnyPublisher<ModelType, Error> {
        let op = ResourceRWOpWrapper(wrapped: updateOperation(model), url: url)
        return transport.execute(op, from: callSite)
    }
}

//

public protocol Deletable: Resource {
    associatedtype ModelType
    associatedtype DeleteOperationType: WriteOperation where
        DeleteOperationType.RequestType == ModelType,
        DeleteOperationType.MethodType: DeletableResourceHTTPMethod

    func deleteOperation(_ model: ModelType) -> DeleteOperationType
}

public extension Deletable {
    func delete(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> AnyPublisher<Void, Error> {
        let op = ResourceWriteOpWrapper(wrapped: deleteOperation(model), url: url)
        return transport.execute(op, from: callSite)
    }
}

// MARK: - wrappers

protocol AnyOperationWrapper where Self: Operation {
    var wrappedType: Operation.Type { get }
}

protocol OperationWrapper: AnyOperationWrapper {
    associatedtype Wrapped: Operation

    var wrapped: Wrapped { get }
}

extension OperationWrapper {
    var wrappedType: Operation.Type { type(of: wrapped) }
}

extension Operation {
    var operationType: Operation.Type {
        if let op = self as? AnyOperationWrapper {
            return op.wrappedType
        } else {
            return type(of: self)
        }
    }
}

struct ResourceReadOpWrapper<Wrapped: ReadOperation>: ReadOperation, OperationWrapper {
    typealias ResponseType = Wrapped.ResponseType
    typealias MethodType = Wrapped.MethodType

    let wrapped: Wrapped

    let url: String

    internal init(wrapped: Wrapped, url: String) {
        self.wrapped = wrapped
        self.url = url
    }

    var headers: Headers { wrapped.headers }
    var method: MethodType { wrapped.method }
    var responseRelativePath: String? { wrapped.responseRelativePath }
}

struct ResourceWriteOpWrapper<Wrapped: WriteOperation>: WriteOperation, OperationWrapper {
    typealias RequestType = Wrapped.RequestType
    typealias MethodType = Wrapped.MethodType

    let wrapped: Wrapped
    let url: String

    internal init(wrapped: Wrapped, url: String) {
        self.wrapped = wrapped
        self.url = url
    }

    var headers: Headers { wrapped.headers }
    var method: MethodType { wrapped.method }
    var request: RequestType { wrapped.request }
}

struct ResourceRWOpWrapper<Wrapped: ReadOperation & WriteOperation>: ReadOperation, WriteOperation, OperationWrapper {
    typealias RequestType = Wrapped.RequestType
    typealias ResponseType = Wrapped.ResponseType
    typealias MethodType = Wrapped.MethodType

    let wrapped: Wrapped
    let url: String

    internal init(wrapped: Wrapped, url: String) {
        self.wrapped = wrapped
        self.url = url
    }

    var headers: Headers { wrapped.headers }
    var method: MethodType { wrapped.method }
    var request: RequestType { wrapped.request }
    var responseRelativePath: String? { wrapped.responseRelativePath }
}
