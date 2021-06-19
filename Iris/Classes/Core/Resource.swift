//
//  File.swift
//  Iris
//
//  Created by Anna Sidorova on 17.06.2021.
//

import Foundation

public protocol Resource {
    var transport: Transport { get }
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
    associatedtype ReadOperationType: ReadOperation
    where
        ReadOperationType.ResponseType == ModelType,
        ReadOperationType.MethodType: RedableResourceHTTPMethod

    func readOperation(_ resourceId: ResourceId<ModelId>) -> ReadOperationType
}

public extension Readable {
    func read(entityWithId id: ResourceId<ModelId> = .this, _ callSite: StackTraceElement = .context()) -> Flow<ModelType> {
        transport.execute(readOperation(id), from: callSite)
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
    func list(_ callSite: StackTraceElement = .context()) -> Flow<[ModelType]> {
        transport.execute(listOperation(), from: callSite)
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
    func create(entity model: NewModelType, _ callSite: StackTraceElement = .context()) -> Flow<ModelType> {
        transport.execute(createOperation(model), from: callSite)
    }
}

//

public protocol Updateable: Resource {
    associatedtype ModelType
    associatedtype UpdateOperationType: ReadOperation & WriteOperation where
        UpdateOperationType.ResponseType == ModelType,
        UpdateOperationType.RequestType == ModelType,
        UpdateOperationType.MethodType: CreatableResourceHTTPMethod

    func createOperation(_ model: ModelType) -> UpdateOperationType
}

public extension Updateable {
    func update(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> Flow<ModelType> {
        transport.execute(createOperation(model), from: callSite)
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
    func delete(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> Flow<Void> {
        transport.execute(deleteOperation(model), from: callSite)
    }
}
