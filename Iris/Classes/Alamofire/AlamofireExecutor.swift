//
//  AlamofireTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Alamofire
import PromiseKit

private let nullString = "(null)"
private let separatorString = "*******************************"

public struct AlamofireExecutor: Executor {
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

    private let level: LogLevel
    private let options: [LogOption]

    public init(level: AlamofireExecutor.LogLevel = .all, options: [AlamofireExecutor.LogOption] = [.jsonPrettyPrint]) {
        self.level = level
        self.options = options
    }

    public func execute(
        context: CallContext,
        data requestData: () throws -> Data?,
        response: @escaping (Swift.Result<OperationResult, Swift.Error>) -> Void) throws -> OperationCancellation {

        var urlRequest = try URLRequest(url: context.url, method: context.method.alamofire)
        urlRequest.allHTTPHeaderFields = context.headers
        urlRequest.httpBody = try requestData()

        let request = AF.request(urlRequest)

        // logging
        logRequest(request: urlRequest, context: context)
        //

        request
            .responseData { ret in
                // logging
                let responseInfo = ResponseInfo(
                    httpResponse: ret.response,
                    data: ret.data,
                    elapsedTime: request.metrics?.taskInterval.duration ?? 0.0,
                    error: ret.error
                )
                self.logResponse(request: ret.request, response: responseInfo, context: context)
                //

                switch ret.result {
                    case .success(let value):
                        response(.success((request.response!, value)))
                    case .failure(let error):
                        response(.failure(error))
                }
            }

        return { request.cancel() }
    }

    // MARK: - Private helpers + pretty logging

    private func logRequest(request: URLRequest, context: CallContext) {

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

    struct ResponseInfo {
        let httpResponse: HTTPURLResponse?
        let data: Data?
        let elapsedTime: TimeInterval
        let error: Error?
    }

    private func logResponse(request: URLRequest?, response: ResponseInfo, context: CallContext) {

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

private extension OperationMethod {
    var alamofire: Alamofire.HTTPMethod {
        return Alamofire.HTTPMethod(rawValue: self.rawValue)
    }
}
