//
//  ExecutorPrinter.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation

public struct ExecutorPrinterResponseInfo {
    public init(httpResponse: HTTPURLResponse? = nil, data: Data? = nil, elapsedTime: TimeInterval, error: Error? = nil) {
        self.httpResponse = httpResponse
        self.data = data
        self.elapsedTime = elapsedTime
        self.error = error
    }
    
    public let httpResponse: HTTPURLResponse?
    public let data: Data?
    public let elapsedTime: TimeInterval
    public let error: Error?
}

public protocol ExecutorPrinter {
    func logRequest(request: URLRequest, context: CallContext)
    func logResponse(request: URLRequest?, response: ExecutorPrinterResponseInfo, context: CallContext)
}
