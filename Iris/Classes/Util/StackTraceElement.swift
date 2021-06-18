//
//  StackTraceElement.swift
//  Iris
//
//  Created by Anna Sidorova on 16.06.2021.
//

import Foundation

public struct StackTraceElement {
    public let `where`: String
    public let offset: Int

    public init(where: String, offset: Int) {
        self.`where` = `where`
        self.offset = offset
    }

    public static func source(file: String = #file, method: String = #function,
                            line: UInt = #line, column: UInt = #column) -> StackTraceElement {
        return StackTraceElement(where: "\(file) \(method) @ [\(line):\(column)]", offset: 0)
    }

    public static func here() -> StackTraceElement {
        fetchInfo(at: 1)
    }

    public static func context() -> StackTraceElement {
        fetchInfo(at: 2)
    }

    private static func fetchInfo(at index: Int) -> StackTraceElement {
        let stack = Thread.callStackSymbols

        guard stack.count > 1 else { return .here() }

        let record = stack[index + 1].split(separator: " ", maxSplits: 3).map { String($0) }

        let parts = record.last!.components(separatedBy: " + ")

        let mangled = parts[0]
        let offset = Int(parts[1]) ?? 0

        var callMethod: String
        if mangled.first == "$" {
            let strippedInPlace = mangled.replacingOccurrences(of: "33_[A-Z0-9]{32}LL", with: "", options: .regularExpression)
            callMethod = _stdlib_demangleName(strippedInPlace)
        } else {
            callMethod = _stdlib_demangleName(mangled)
        }

        return StackTraceElement(where: callMethod, offset: offset)
    }
}

@_silgen_name("swift_demangle")
public
func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
) -> UnsafeMutablePointer<CChar>?

public func _stdlib_demangleName(_ mangledName: String) -> String {
    return mangledName.utf8CString.withUnsafeBufferPointer {
        (mangledNameUTF8CStr) in

        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8CStr.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)

        if let demangledNamePtr = demangledNamePtr {
            let demangledName = String(cString: demangledNamePtr)
            free(demangledNamePtr)
            return demangledName
        }
        return mangledName
    }
}
