//
//  AlamofireTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Alamofire
import Combine

private let nullString = "(null)"
private let separatorString = "*******************************"

private struct ResponseInfo {
    let httpResponse: HTTPURLResponse?
    let data: Data?
    let elapsedTime: TimeInterval
    let error: Error?
}

public struct AlamofireExecutor: Executor {

    private let logger: AlamofireLogger

    public init(loggingConfig: AlamofireLogger = AlamofireLogger()) {
        self.logger = loggingConfig
    }

    public func execute(context: CallContext, data requestData: () throws -> Data?) -> AnyPublisher<OperationResult, Swift.Error> {

        do {
            var urlRequest = try URLRequest(url: context.url, method: context.method.alamofire)
            urlRequest.allHTTPHeaderFields = context.headers
            urlRequest.httpBody = try requestData()

            let request = AF.request(urlRequest)

            // logging
            logger.logRequest(request: urlRequest, context: context)
            //

            return request
                .publishData()
                .handleEvents(receiveOutput: {
                    // logging
                    let responseInfo = ResponseInfo(
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
                            return ($0.response!, data)
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

public struct AlamofireLogger {
    public enum LogLevel {
        case none
        case all
        case info
        case error
    }

    public enum LogOption {
        case onlyDebug
        case jsonPrettyPrint
        case includeSeparator

        public static var defaultOptions: [LogOption] {
            return [.onlyDebug, .jsonPrettyPrint, .includeSeparator]
        }
    }

    public init(level: LogLevel = .all, options: [LogOption] = [.jsonPrettyPrint]) {
        self.level = level
        self.options = options
    }

    let level: LogLevel
    let options: [LogOption]

    fileprivate func logRequest(request: URLRequest, context: CallContext) {

        let method = request.httpMethod!
        let url = request.url?.absoluteString ?? nullString
        let headers = prettyPrintedString(from: request.allHTTPHeaderFields) ?? nullString

        // separator
        let openSeparator = options.contains(.includeSeparator) ? "\(separatorString)\n" : ""
        let closeSeparator = options.contains(.includeSeparator) ? "\n\(separatorString)" : ""

        switch (level) {
            case .all:
                let prettyPrint = options.contains(.jsonPrettyPrint)
                let body = string(from: request.httpBody, prettyPrint: prettyPrint) ?? nullString
                context.printer.print(
                    "\(openSeparator)[Request] \(method) '\(url)':\n\n[Headers]\n\(headers)\n\n[Body]\n\(body)\(closeSeparator)",
                    phase: .request,
                    callSite: context.callSite
                )

            case .info:
                context.printer.print(
                    "\(openSeparator)[Request] \(method) '\(url)'\(closeSeparator)",
                    phase: .request,
                    callSite: context.callSite
                )

            default:
                break
        }
    }

    fileprivate func logResponse(request: URLRequest?, response: ResponseInfo, context: CallContext) {

        guard level != .none else {
            return
        }

        let httpResponse = response.httpResponse
        let data = response.data
        let elapsedTime = response.elapsedTime
        let error = response.error

        if request == nil && response.httpResponse == nil {
            return
        }

        // options
        let prettyPrint = options.contains(.jsonPrettyPrint)

        // request
        let requestMethod = request?.httpMethod ?? nullString
        let requestUrl = request?.url?.absoluteString ?? nullString

        // response
        let responseStatusCode = httpResponse?.statusCode ?? 0
        let responseHeaders = prettyPrintedString(from: httpResponse?.allHeaderFields) ?? nullString
        let responseData = string(from: data, prettyPrint: prettyPrint) ?? nullString

        // time
        let elapsedTimeString = String(format: "[%.4f s]", elapsedTime)

        // separator
        let openSeparator = options.contains(.includeSeparator) ? "\(separatorString)\n" : ""
        let closeSeparator = options.contains(.includeSeparator) ? "\n\(separatorString)" : ""

        // log
        let success = (error == nil)
        let responseTitle = success ? "Response" : "Response Error"
        switch level {
            case .all:
                context.printer.print(
                    "\(openSeparator)[\(responseTitle)] \(responseStatusCode) '\(requestUrl)' \(elapsedTimeString):\n\n[Headers]:\n\(responseHeaders)\n\n[Body]\n\(responseData)\(closeSeparator)",
                    phase: .response(success: success),
                    callSite: context.callSite
                )
            case .info:
                context.printer.print(
                    "\(openSeparator)[\(responseTitle)] \(responseStatusCode) '\(requestUrl)' \(elapsedTimeString)\(closeSeparator)",
                    phase: .response(success: success),
                    callSite: context.callSite)
            case .error:
                if let error = error {
                    context.printer.print(
                        "\(openSeparator)[\(responseTitle)] \(requestMethod) '\(requestUrl)' \(elapsedTimeString) s: \(error)\(closeSeparator)",
                        phase: .response(success: success),
                        callSite: context.callSite
                    )
                }
            default:
                break
        }
    }

    private func string(from data: Data?, prettyPrint: Bool) -> String? {

        guard let data = data else {
            return nil
        }

        var response: String? = nil

        if prettyPrint,
           let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyString = prettyPrintedString(from: json) {
            response = prettyString
        }

        else if let dataString = String.init(data: data, encoding: .utf8) {
            response = dataString
        }

        return response
    }

    private func prettyPrintedString(from json: Any?) -> String? {
        guard let json = json else {
            return nil
        }

        var response: String? = nil

        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let dataString = String.init(data: data, encoding: .utf8) {
            response = dataString
        }

        return response
    }

}
