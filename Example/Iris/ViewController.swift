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
    private var task: Task<Void, Never>?

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
        task = Task {
            do {
                //            let result = TestResource(transport: transport).create(entity: TestOperation.Request())
                let result = try await transport.execute(TestOperation())
                print(result)
            } catch {
                print(error)
            }
            task = nil
        }

        redraw()
    }

    @IBAction func cancel() {
        task?.cancel()
        redraw()
    }

    private func redraw() {
        self.cancelButton.isEnabled = task != nil
        self.startButton.isEnabled = task == nil
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
                <<<{ _ in try? await delay(.seconds(1)) },
        headers:
                <<<{ _ in Headers(.authorization(.basic(login: "John", password: "Doe"))) },
                .auth(yes: false),
                <<<{ _ in Headers([.init(key: .contentType, value: "application/json")]) },
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
        Self { _, _ in try await delay(interval) }
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

func delay(_ delayInterval: DispatchTimeInterval) async throws {
    try await Task.sleep(delayInterval)
}

extension Task where Success == Never, Failure == Never {
    static func sleep(_ time: DispatchTimeInterval) async throws {
        try await sleep(nanoseconds: time.nanoseconds)
    }

    static func sleep(_ time: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(time * 1_000_000_000))
    }
}

extension DispatchTimeInterval {
    var nanoseconds: UInt64 {
        switch self {
        case .seconds(let value):
            return .init(value * 1_000_000_000)
        case .milliseconds(let value):
            return .init(value * 1_000_000)
        case .microseconds(let value):
            return .init(value * 1_000)
        case .nanoseconds(let value):
            return .init(value)
        case .never:
            return .max
        @unknown default:
            return .max
        }
    }
}

extension DispatchTimeInterval {
    var timeinterval: TimeInterval {
        switch self {
        case .seconds(let value):
            return .init(value)
        case .milliseconds(let value):
            return .init(Double(value) / 1000.0)
        case .microseconds(let value):
            return .init(Double(value) / 1_000_000.0)
        case .nanoseconds(let value):
            return .init(Double(value) / 1_000_000_000.0)
        case .never:
            return .infinity
        @unknown default:
            return .infinity
        }
    }
}
