//
//  AlamofireTransport.swift
//  Iris
//
//  Created by Anna Sidorova on 15.06.2021.
//

import Foundation
import Alamofire
import AlamofireActivityLogger
import PromiseKit

public struct AlamofireExecutor : Executor {
    public init() {}
    
    public func execute(
        operation: Operation,
        context: CallContext,
        data requestData: () throws -> Data?,
        response: @escaping (Swift.Result<OperationResult, Error>) -> Void) throws -> OperationCancellation {

        var urlRequest = try URLRequest(url: operation.url,
                                        method: operation.method.alamofire,
                                        headers: operation.headers)

        urlRequest.httpBody = try requestData()

        let request = Alamofire.request(urlRequest)

        request
            .log(options: [.jsonPrettyPrint], printer: PrinterWrapper(context: context))
            .responseData { ret in
                switch ret.result {
                    case .success(let value):
                        response(.success((request.response!, value)))
                    case .failure(let error):
                        response(.failure(error))
                }
            }

        return { request.cancel() }
    }
}

private struct PrinterWrapper : AlamofireActivityLogger.Printer {
    let context: CallContext

    internal init(context: CallContext) {
        self.context = context
    }

    func print(_ string: String, phase: AlamofireActivityLogger.Phase) {
        context.printer.print(string, phase: phase.networkOperationPhase, callSite: context.callSite)
    }
}

private extension HTTPMethod {
    var alamofire: Alamofire.HTTPMethod {
        return Alamofire.HTTPMethod(rawValue: self.rawValue)!
    }
}

extension AlamofireActivityLogger.Phase {
    var networkOperationPhase: Phase {
        switch self {
            case .request:
                return .request
            case .response(success: let success):
                return .response(success: success)
        }
    }
}
