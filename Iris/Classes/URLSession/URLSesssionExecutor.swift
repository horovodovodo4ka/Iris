//
//  URLSesssionExecutor.swift
//  Iris-iOS
//
//  Created by Anna Sidorova on 27.06.2021.
//

import Foundation
import Combine

public class URLSessionExecutor: Executor {

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

    public init(printer: ExecutorPrinter = DefaultExecutorPrinter()) {
        self.logger = printer
    }

    public func execute(context: CallContext, data requestData: () throws -> Data?) -> AnyPublisher<OperationResult, Swift.Error> {
        do {
            guard let url = URL(string: context.url) else { throw Error.invalidURL(url: context.url) }
            var urlRequest = try URLRequest(url: url)
            urlRequest.httpMethod = context.method.rawValue
            urlRequest.allHTTPHeaderFields = context.headers
            urlRequest.httpBody = try requestData()

            let request = URLSession.shared.dataTaskPublisher(for: urlRequest)

            // logging
            logger.logRequest(request: urlRequest, context: context)
            //

            let start = DispatchTime.now()

            struct Response {
                let request: URLRequest
                let response: HTTPURLResponse?
                let data: Data?
                let error: Swift.Error?
                let duration: TimeInterval

                var result: Swift.Result<Data, Swift.Error> {
                    if let data = data {
                        return .success(data)
                    } else {
                        return .failure(error!)
                    }
                }
            }

            return request
                .map {
                    Response(request: urlRequest, response: $0.response as? HTTPURLResponse, data: $0.data, error: nil, duration: start.measure())
                }
                .catch {
                    Just(Response(request: urlRequest, response: nil, data: nil, error: $0, duration: start.measure()))
                }
                .handleEvents(receiveOutput: {
                    // logging
                    let responseInfo = ExecutorPrinterResponseInfo(
                        httpResponse: $0.response,
                        data: $0.data,
                        elapsedTime: $0.duration,
                        error: $0.error
                    )

                    self.logger.logResponse(request: $0.request, response: responseInfo, context: context)
                })
                .tryMap {
                    switch $0.result {
                        case .success(let data):
                            return ($0.response, data)
                        case .failure(let error):
                            throw error as Swift.Error
                    }
                }
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
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
