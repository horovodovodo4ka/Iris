//
//  AlamofireTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Alamofire
import Combine
import Iris
#if canImport(IrisLogging)
import IrisLogging
#endif

public struct AlamofireExecutor: Executor {

    private let logger: ExecutorPrinter
    private let session: Alamofire.Session

    public init(printer: ExecutorPrinter = DefaultExecutorPrinter(), session: Alamofire.Session = .default) {
        self.logger = printer
        self.session = session
    }

    public func execute(context: CallContext, data requestData: Data?) async throws -> OperationResult {

        var urlRequest = try URLRequest(url: context.url, method: context.method.alamofire)
        urlRequest.allHTTPHeaderFields = context.headers
        urlRequest.httpBody = requestData
        if let timeout = context.timeout {
            urlRequest.timeoutInterval = timeout
        }

        let request = session.request(urlRequest)

        // logging
        logger.logRequest(request: urlRequest, context: context)
        //

        do {
            return try await withCheckedThrowingContinuation { [logger] cont in
                request
                    .responseData(emptyResponseCodes: Set(200..<300)) {
                        let responseInfo = ExecutorPrinterResponseInfo(
                            httpResponse: $0.response,
                            data: $0.data,
                            elapsedTime: request.metrics?.taskInterval.duration ?? 0.0,
                            error: $0.error
                        )

                        logger.logResponse(request: $0.request, response: responseInfo, context: context)

                        switch $0.result {
                        case .success(let data):
                            cont.resume(returning: ($0.response, data))
                        case .failure(let error):
                            cont.resume(throwing: error)
                        }
                    }
            }
        } catch {
            if error is CancellationError {
                request.cancel()
            }
            throw error
        }
    }
}

private extension OperationMethod {
    var alamofire: Alamofire.HTTPMethod {
        return Alamofire.HTTPMethod(rawValue: self.rawValue)
    }
}

// MARK: - logging
