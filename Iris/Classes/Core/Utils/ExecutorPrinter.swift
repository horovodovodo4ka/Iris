//
//  ExecutorPrinter.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation

public struct ExecutorPrinterResponseInfo {
    let httpResponse: HTTPURLResponse?
    let data: Data?
    let elapsedTime: TimeInterval
    let error: Error?
}

public protocol ExecutorPrinter {
    func logRequest(request: URLRequest, context: CallContext)
    func logResponse(request: URLRequest?, response: ExecutorPrinterResponseInfo, context: CallContext)
}
