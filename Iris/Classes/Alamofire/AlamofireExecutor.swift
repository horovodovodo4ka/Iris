//
//  AlamofireTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Alamofire
import Combine

public struct AlamofireExecutor: Executor {

    private let logger: ExecutorPrinter

    public init(printer: ExecutorPrinter = DefaultExecutorPrinter()) {
        self.logger = printer
    }

    public func execute(context: CallContext, data requestData: Data?) -> AnyPublisher<OperationResult, Swift.Error> {

        do {
            var urlRequest = try URLRequest(url: context.url, method: context.method.alamofire)
            urlRequest.allHTTPHeaderFields = context.headers
            urlRequest.httpBody = requestData

            let request = AF.request(urlRequest)

            // logging
            logger.logRequest(request: urlRequest, context: context)
            //

            return request
                .publishData()
                .handleEvents(receiveOutput: {
                    // logging
                    let responseInfo = ExecutorPrinterResponseInfo(
                        httpResponse: $0.response,
                        data: $0.data,
                        elapsedTime: request.metrics?.taskInterval.duration ?? 0.0,
                        error: $0.error
                    )

                    self.logger.logResponse(request: $0.request, response: responseInfo, context: context)
                })
                .tryMap {
                    switch $0.result {
                        case .success(let data):
                            return ($0.response, data)
                        case .failure(let error):
                            throw error as Error
                    }
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

private extension OperationMethod {
    var alamofire: Alamofire.HTTPMethod {
        return Alamofire.HTTPMethod(rawValue: self.rawValue)
    }
}

// MARK: - logging
