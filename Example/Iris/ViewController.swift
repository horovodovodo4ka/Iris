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
    private var scope = [AnyCancellable]()

    let transport = Transport(
        configuration: .default,
        executor: URLSessionExecutor())

    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        transport.add(middlware: .test)

        cancelButton.isEnabled = false

    }

    @IBAction func start() {

//        let op = TestResource(transport: transport).create(entity: TestOperation.Request())

        let op = transport.execute(TestOperation())

        op.receive(on: DispatchQueue.main)
            .sink {
                if case .failure(let error) = $0 {
                    print(error)
                }
                self.cancel()
            } receiveValue: {
                print($0)
            }
            .store(in: &scope)

        redraw()
    }

    @IBAction func cancel() {
        scope = []
        redraw()
    }

    private func redraw() {
        self.cancelButton.isEnabled = !scope.isEmpty
        self.startButton.isEnabled = scope.isEmpty
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
        barrier:
                <<<{ _ in delay(.seconds(1)) },
        headers:
                <<<{ _ in Headers(.authorization(.basic(login: "John", password: "Doe"))) },
                .auth(yes: true),
        validate:
                .statusCode,
        recover:
                .retryAfter(interval: .seconds(3)),
        success:
                <<<{ print($1 as Any) }
    )
}

//

extension Middleware.Recover {
    static func retryAfter(interval: DispatchTimeInterval) -> Self {
        Self { _, _ in delay(interval) }
    }
}

extension Middleware.RequestHeaders {
    static func auth(yes: @escaping @autoclosure () -> Bool) -> Self {
        Self { _ in
            guard yes() else { return .empty }
            return Headers(.authorization(.bearer("ABCDEF01234567890")))
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
        var url: String { "https://reqbin.com/echo/post/json" }
//    var url: String { "https://google.ru" }
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

extension TestOperation: IndirectResponseOperation {
    var responseRelativePath: String { ".success" }
}

// some sample data

enum Authorization: CustomStringConvertible {
    case basic(login: String, password: String)
    case bearer(_ token: String)

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

extension Header {
    static func authorization(_ auth: Authorization) -> Self {
        Header(key: HeaderKey(name: "Authorization"), value: auth)
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

func delay<Failure>(_ delayInterval: DispatchTimeInterval) -> AnyPublisher<Void, Failure> {
    Delay(delayInterval).setFailureType(to: Failure.self).eraseToAnyPublisher()
}
