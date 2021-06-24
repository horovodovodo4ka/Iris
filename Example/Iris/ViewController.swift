//
//  ViewController.swift
//  Iris
//
//  Created by Anna on 06/15/2021.
//  Copyright (c) 2021 Anna. All rights reserved.
//

import UIKit
import Iris
import Combine

class ViewController: UIViewController {
    private var store = [AnyCancellable]()
    let transport = Transport(
        configuration: .default,
        executor: AlamofireExecutor())

    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.


        transport.add(middlware: .test)

        // cancel
//        store = []

//            .done { v in
//                print(v.headers[.contentType] ?? "")
//                print(v.model)
//            }
//            .catch { e in
//                print(e.localizedDescription)
//            }

//        after(seconds: 3).done {
//            f.cancel()
//        }

//        _ = TestResource(transport: transport)
//            .create(entity: TestOperation.Request())
//            .tap {
//                print($0)
//            }

        cancelButton.isEnabled = false

    }

    @IBAction func start() {
        cancelButton.isEnabled = true
        startButton.isEnabled = false

        transport.executeWithMeta(TestOperation())
            .handleEvents(receiveCancel: {
                self.cancelButton.isEnabled = false
                self.startButton.isEnabled = true
            })
            .map {
                Result.success($0)
            }
            .catch {
                Just(.failure($0))
            }
            .receive(on: DispatchQueue.main)
            .sink {
                switch $0 {
                    case .success(let v):
                        print(v.headers[.contentType] ?? "")
                        print(v.model)
                    case .failure(let error):
                        print(error)
                }
            }
            .store(in: &store)

    }

    @IBAction func cancel() {
        store = []
    }
}

// transport

extension TransportConfig {
    static let `default` = TransportConfig(
        printer: AstarothPrinter(),
        encoder: Json.encoder,
        decoder: Json.decoder
    )
}

// middleware
extension Middleware {
    static let test = Middleware(
//        barrier: <<<{ _ in Delay(.seconds(5)).eraseToAnyPublisher() },
        headers:
            <<<{ _ in Headers([.authorization: Authorization.basic(login: "John", password: "Doe")]) },
            .auth(yes: true),
        validate: .statusCode,
        recover: .retryAfter(interval: .seconds(3))
    )
}

//

extension Middleware.Recover {
    static func retryAfter(interval: DispatchTimeInterval) -> Self {
        Self { _, _ in
            Delay(interval).setFailureType(to: Error.self).eraseToAnyPublisher()
//            after(seconds: seconds).then { _ -> Promise<Void> in .value(()) }
        }
    }
}

extension Middleware.RequestHeaders {
    static func auth(yes: @escaping @autoclosure () -> Bool) -> Self {
        Self { _ in
            guard yes() else { return .empty }
            return Headers([.authorization: Authorization.bearer(token: "ABCDEF01234567890")])
        }
    }
}

// resource
struct TestResource: Creatable {
    let transport: Transport

    typealias ModelType = TestOperation.ResponseType

    func createOperation(_ model: TestOperation.RequestType) -> TestOperation {
        TestOperation()
    }
}

// operation

protocol ApiOperation: Iris.Operation {}

extension ApiOperation {
//    var url: String { "https://reqbin.com/echo/post/json" }
        var url: String { "https://google.ru" }
    //    var url: String { "https://exampleqqq.com" }
}

struct TestOperation: ApiOperation, ReadOperation, WriteOperation {

    let headers = Headers.empty

    // MARK: Read
    typealias ResponseType = String
    //    typealias ResponseType = Response

    struct Response: Decodable {
        var success: String
    }

    // MARK: Write
    typealias RequestType = Request

    struct Request: Encodable {
        var id = 78912
        var customer = "Jason Sweet[ ? # ]"
        var quantity = 1
        var price = 18.00
        var testABC = ABC()
        var nexting = [[1], [2, 3], [4, 5, 6]]
        var testArr = [1, 2, 3]
        var testDict = ["a": 1, "b": 2, "c[]": 3]

        struct ABC: Encodable {
            var b = 1
            var c = "a[]"
        }
    }

    var request: Request { Request() }
}

extension TestOperation: PostOperation {}

extension TestOperation: IndirectModelOperation {
    var responseRelativePath: String { ".success" }
}

enum Authorization: CustomStringConvertible {
    case basic(login: String, password: String)
    case bearer(token: String)

    var description: String {
        switch self {
            case let .basic(login, password):
                guard let token = "\(login):\(password)".data(using: .utf8)?.base64EncodedString() else { return "" }
                return "Basic \(token)"
            case let .bearer(token):
                return "Bearer \(token)"
        }
    }
}

struct Delay: Publisher {
    typealias Output = Void
    typealias Failure = Never

    private let future: Future<Output, Failure>

    init(_ delayInterval: DispatchTimeInterval) {
        future = Future { complete in
            DispatchQueue.global().asyncAfter(deadline: .now() + delayInterval) {
                complete(.success(()))
            }
        }
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        future.receive(subscriber: subscriber)
    }
}
