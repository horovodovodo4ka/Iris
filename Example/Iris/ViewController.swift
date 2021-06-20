//
//  ViewController.swift
//  Iris
//
//  Created by Anna on 06/15/2021.
//  Copyright (c) 2021 Anna. All rights reserved.
//

import UIKit
import Iris
import PromiseKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let transport = Transport(
            configuration: .default,
            executor: AlamofireExecutor())

        transport.add(middlware: .test)

        transport.execute(TestOperation())
            .done { _ in
                print("success")
            }
            .catch {
                print($0.localizedDescription)
            }

//        _ = TestResource(transport: transport)
//            .create(entity: TestOperation.Request())
//            .tap {
//                print($0)
//            }

        let e = BadStateError(cause: Exception(message: "Boo!\""))

        blah()

        let r = (try? QueryString().encode(TestOperation.Request())) ?? ""
        print(r)
        print(e)
    }

    private func blah() {
        let st1: StackTraceElement = .context()
        let st2: StackTraceElement = .here()
        let st3: StackTraceElement = .source()
        let st4 = some
        let st5 = stat()
        let st6 = { StackTraceElement.here() }()
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
    static let `default` = TransportConfig(printer: AstarothPrinter(stringLimit: 200),
                                           encoder: Json.encoder(),
                                           decoder: Json.decoder())
}

extension Recover {
    static func retryAfter(seconds: TimeInterval) -> Recover {
        Recover { _, _ in
            after(seconds: seconds) .then { _ -> Promise<Void> in .value(()) }
        }
    }
}

extension Middleware {
    static let test = Middleware(
        validate: .statusCode,
        recover: .retryAfter(seconds: 3)
    )
}

// resource
struct TestResource: Creatable {

    typealias ModelType = TestOperation.Response
    typealias ReadOperationType = TestOperation

    let transport: Transport

    func createOperation(_ model: TestOperation.Request) -> TestOperation {
        TestOperation()
    }
}

// operation

struct TestOperation: ReadOperation, WriteOperation, PostOperation {
//    let method = Get()

    struct Request: Encodable {
        var id = 78912
        var customer = "Jason Sweet[ ? # ]"
        var quantity = 1
        var price = 18.00
        var testA = A()
        var nexting = [[1], [2, 3], [4, 5, 6]]
        var testArr = [1, 2, 3]
        var testDict = ["a": 1, "b": 2, "c[]": 3]

        struct A: Encodable {
            var b = 1
            var c = "a[]"
        }
    }

    struct Response: Decodable {
        var success: String
        var foo: Bool
    }

    typealias RequestType = Request
    typealias ResponseType = Response

    var headers: [String: String] { [:] }

//    var url: String { "https://reqbin.com/echo/post/json" }
    var url: String { "https://google.ru" }
//    var url: String { "https://exampleqqq.com" }

    var request: Request {
        Request()
    }
}

typealias Exception = Iris.Exception

class BadStateError: Exception {}
