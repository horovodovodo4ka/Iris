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
        cancelButton.isEnabled = true
        startButton.isEnabled = false

        let op = TestResource(transport: transport).create(entity: TestOperation.Request())

        //        let op = transport.execute(TestOperation())

        op
            .receive(on: DispatchQueue.main)
            .finally {

            }
            .sink {
                switch $0 {
                    case .finished:
                        self.cancelButton.isEnabled = false
                        self.startButton.isEnabled = true
                    case .failure(let error):
                        print(error)
                }
            } receiveValue: {
                print($0)
            }
//            .result()
//            .sink {
//                switch $0 {
//                    case .success(let v):
//                        print(v)
//                        //                        print(v.headers[.contentType] ?? "")
//                        //                        print(v.model)
//                    case .failure(let error):
//                        print(error)
//                }
//            }
            .store(in: &scope)

    }

    @IBAction func cancel() {
        scope = []
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
            return Headers(.authorization(.bearer(token: "ABCDEF01234567890")))
        }
    }
}

// resource
struct TestResource: Creatable {
    var url: String { "https://reqbin.com/echo/post/json" }

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
    //    typealias ResponseType = String
    typealias ResponseType = Response

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

// extension TestOperation {
//    var responseRelativePath: String? { ".success" }
// }

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

extension Header {
    static func authorization(_ auth: Authorization) -> Self {
        Header(key: HeaderKey.authorization, value: auth)
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

extension Publisher {
    func finally(_ block: @escaping () -> Void) -> AnyPublisher<Output, Failure> {
        handleEvents(receiveCompletion: { _ in block() }, receiveCancel: { block() }).eraseToAnyPublisher()
    }

    func result() -> AnyPublisher<Result<Output, Failure>, Never> {
        map {
            Result.success($0)
        }
        .catch {
            Just(.failure($0))
        }
        .eraseToAnyPublisher()
    }
}

// extension Publisher {
//    func done()
// }
