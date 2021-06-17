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
    func read(entityWithId id: ResourceId<ModelId> = .this, _ callSite: StackTraceElement) -> Flow<ModelType> {
        transport.execute(readOperation(id), from: callSite)
    }

    func read(entityWithId id: ResourceId<ModelId> = .this, file: StaticString = #file, method: StaticString = #function,
              line: UInt = #line, column: UInt = #column) -> Flow<ModelType> {

        read(entityWithId: id, StackTraceElement(filename: file, method: method, line: line, column: column))
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
    func list(_ callSite: StackTraceElement) -> Flow<[ModelType]> {
        transport.execute(listOperation(), from: callSite)
    }

    func list(file: StaticString = #file, method: StaticString = #function,
              line: UInt = #line, column: UInt = #column) -> Flow<[ModelType]> {

        list(StackTraceElement(filename: file, method: method, line: line, column: column))
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
    func create(entity model: NewModelType, _ callSite: StackTraceElement) -> Flow<ModelType> {
        transport.execute(createOperation(model), from: callSite)
    }

    func create(entity model: NewModelType, file: StaticString = #file, method: StaticString = #function,
              line: UInt = #line, column: UInt = #column) -> Flow<ModelType> {

        create(entity: model, StackTraceElement(filename: file, method: method, line: line, column: column))
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
    func update(entity model: ModelType, _ callSite: StackTraceElement) -> Flow<ModelType> {
        transport.execute(createOperation(model), from: callSite)
    }

    func update(entity model: ModelType, file: StaticString = #file, method: StaticString = #function,
                line: UInt = #line, column: UInt = #column) -> Flow<ModelType> {

        update(entity: model, StackTraceElement(filename: file, method: method, line: line, column: column))
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
    func delete(entity model: ModelType, _ callSite: StackTraceElement) -> Flow<Void> {
        transport.execute(deleteOperation(model), from: callSite)
    }

    func delete(entity model: ModelType, file: StaticString = #file, method: StaticString = #function,
                line: UInt = #line, column: UInt = #column) -> Flow<Void> {

        delete(entity: model, StackTraceElement(filename: file, method: method, line: line, column: column))
    }
}
