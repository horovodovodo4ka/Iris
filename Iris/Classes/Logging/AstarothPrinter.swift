//
//  AstarothPrinter.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Astaroth
import Iris

// swiftlint:disable:next identifier_name
public let Network = StringTag("Network")

public class AstarothPrinter: Printer {

    private let stringLimit: Int
    public init(stringLimit: Int = .max) {
        self.stringLimit = stringLimit
    }

    private var requestString: String = ""
    private var responseString: String = ""

    public func print(_ string: String, phase: Phase, callSite: Iris.StackTraceElement) {
        switch phase {
            case .request:
                let string = String(string.prefix(stringLimit))
                requestString = string
                Log.d(Network, string, callSite.astaroth)
            case .response(_):
                responseString = String(string.prefix(stringLimit))
            case .decoding(let success):
                let string = "\(requestString)\n\(responseString)\n\(string)"
                if success {
                    Log.i(Network, string, callSite.astaroth)
                } else {
                    Log.e(Network, string, callSite.astaroth)
                }
        }
    }
}

private extension Iris.StackTraceElement {
    var astaroth: Astaroth.StackTraceElement {
        Astaroth.StackTraceElement(filename: "", method: `where`, line: 0, column: 0)
    }
}
