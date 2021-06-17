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

//

public enum ResourceId<Id> {
    case this
    case element(Id)
}

public protocol Readable: Resource {
    associatedtype ModelId
    associatedtype ModelType
    associatedtype ReadOperationType: ReadOperation where
        ReadOperationType.ResponseType == ModelType

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
        ListOperationType.ResponseType == [ModelType]

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
        CreateOperationType.RequestType == NewModelType

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
    associatedtype CreateOperationType: ReadOperation & WriteOperation where
        CreateOperationType.ResponseType == ModelType,
        CreateOperationType.RequestType == ModelType

    func createOperation(_ model: ModelType) -> CreateOperationType
}

public extension Updateable {
    func update(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> Flow<ModelType> {
        transport.execute(createOperation(model), from: callSite)
    }
}

//

public protocol Deletable: Resource {
    associatedtype ModelType
    associatedtype CreateOperationType: WriteOperation where
        CreateOperationType.RequestType == ModelType

    func deleteOperation(_ model: ModelType) -> CreateOperationType
}

public extension Deletable {
    func delete(entity model: ModelType, _ callSite: StackTraceElement = .context()) -> Flow<Void> {
        transport.execute(deleteOperation(model), from: callSite)
    }
}
