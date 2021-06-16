//
//  StackTraceElement.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public struct StackTraceElement {
    public let filename: StaticString
    public let method: StaticString
    public let line: UInt
    public let column: UInt

    public init(filename: StaticString, method: StaticString, line: UInt, column: UInt) {
        self.filename = filename
        self.method = method
        self.line = line
        self.column = column
    }

    public static func here(file: StaticString = #file, method: StaticString = #function,
                            line: UInt = #line, column: UInt = #column) -> StackTraceElement {
        return StackTraceElement(filename: file, method: method, line: line, column: column)
    }
}
