//
//  ViewController.swift
//  Iris
//
//  Created by Anna on 06/15/2021.
//  Copyright (c) 2021 Anna. All rights reserved.
//

import UIKit
import Iris

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let transport = Transport(
            configuration: .default,
            executor: AlamofireExecutor())

        transport.add(middlware: .test)

//        transport.execute(TestOperation()).tap {
//            print($0)
//        }

        TestResource(transport: transport).read().tap {
            print($0)
        }

        blah()
    }

    private func blah() {
        let st1: StackTraceElement = .context()
        let st2: StackTraceElement = .here()
        let st3: StackTraceElement = .source()
        let st4 = some
        let st5 = stat()
    }

    var some: StackTraceElement {
        .here()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

func stat() -> StackTraceElement {
    .here()
}
// transport

extension TransportConfig {
    static let `default` = TransportConfig(printer: AstarothPrinter(), encoder: jsonEncoder, decoder: jsonDecoder)
}

import PromiseKit

extension Middleware {
    static let test = Middleware(
        validate: statusCodeValidator,
        recover: { _, e in
            after(seconds: 3)
                .then { _ -> Promise<Void> in .value(()) }
        }
    )
}

// resource

struct TestResource: Readable {
    typealias ModelId = Int
    typealias ModelType = TestOperation.Response
    typealias ReadOperationType = TestOperation

    let transport: Transport

    func readOperation(_ resourceId: ResourceId<Int>) -> TestOperation {
        TestOperation()
    }
}

// operation

struct TestOperation: ReadOperation, WriteOperation {

    struct Request: Encodable {
        var id = 78912
        var customer = "Jason Sweet"
        var quantity = 1
        var price = 18.00
    }

    struct Response: Decodable {
        var success: String
    }

    typealias RequestType = Request
    typealias ResponseType = Response

    var headers: [String : String] { [:] }

    var url: String { "https://reqbin.com/echo/post/json" }
//    var url: String { "https://google.ru" }

    var request: Request {
        Request()
    }
}
