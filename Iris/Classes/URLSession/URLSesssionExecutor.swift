//
//  URLSesssionExecutor.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation
import Combine

public struct URLSessionExecutor: Executor {

    public enum Error: LocalizedError {
        case invalidURL(url: String)

        public var errorDescription: String? {
            switch self {
                case .invalidURL(url: let url):
                    return "Invalid url: \(url)"
            }
        }
    }

    private let logger: ExecutorPrinter
    private let session: URLSession

    public init(printer: ExecutorPrinter = DefaultExecutorPrinter(), session: URLSession = .shared) {
        self.logger = printer
        self.session = session
    }

    public func execute(context: CallContext, data requestData: Data?) async throws -> OperationResult {

        guard let url = URL(string: context.url) else { throw Error.invalidURL(url: context.url) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = context.method.rawValue
        urlRequest.allHTTPHeaderFields = context.headers
        urlRequest.httpBody = requestData
        if let timeout = context.timeout {
            urlRequest.timeoutInterval = timeout
        }

        // logging
        logger.logRequest(request: urlRequest, context: context)
        //

        let start = DispatchTime.now()

        do {
            let (data, response) = try await session.data(for: urlRequest)

            let responseInfo = ExecutorPrinterResponseInfo(
                httpResponse: response as? HTTPURLResponse,
                data: data,
                elapsedTime: start.measure(),
                error: nil
            )

            logger.logResponse(request: urlRequest, response: responseInfo, context: context)

            return (response as? HTTPURLResponse, data)
        } catch {
            let responseInfo = ExecutorPrinterResponseInfo(
                httpResponse: nil,
                data: nil,
                elapsedTime: start.measure(),
                error: error
            )

            logger.logResponse(request: urlRequest, response: responseInfo, context: context)

            throw error
        }
    }
}

private extension DispatchTime {
    func measure() -> TimeInterval {
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - self.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests

        return timeInterval
    }
}
