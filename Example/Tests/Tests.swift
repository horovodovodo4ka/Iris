// https://github.com/Quick/Quick

import XCTest
import Quick
import Nimble
import Iris

struct TestOperation: ReadOperation, WriteOperation, PostOperation, IndirectModelOperation {
    // MARK: Operation
    let headers: Headers = .empty

    let url: String

    // MARK: WriteOperation
//    typealias RequestType = Request

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

    var request: Request {
        Request()
    }

    // MARK: ReadOperation
    typealias ResponseType = String
//
//    struct Response: Decodable {
//        var success: String
//    }

    // MARK: - IndirectModelOperation
    var responseRelativePath: String { ".success" }
}

class BasicInteractions: QuickSpec {
    override func spec() {
        let transport = Transport(
            configuration: TransportConfig(printer: NoopPrinter(), encoder: Json.encoder, decoder: Json.decoder),
            executor: AlamofireExecutor()
        )

        describe("Basic interactions") {
            it("Send and resieves JSON, response decoded with json path") {

                waitUntil(timeout: .seconds(6)) { done in
                    let flow = transport.execute(TestOperation(url: "https://reqbin.com/echo/post/json"))

                    DispatchQueue.global().async {
                        Thread.sleep(forTimeInterval: 5)

                        expect(flow.result.map { ^$0 }).to(beSuccess { value in
                            expect(value).to(equal("true"))
                        })

                        done()
                    }
                }
            }
        }
    }
}

// MARK: -
prefix operator ^

import PromiseKit
extension PromiseKit.Result {
    static prefix func ^ (lhs: Self) -> Swift.Result<T, Error> {
        switch lhs {
            case .fulfilled(let value):
                return .success(value)
            case .rejected(let error):
                return .failure(error)
        }
    }
}
