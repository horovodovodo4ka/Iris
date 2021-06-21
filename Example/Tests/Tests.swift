// https://github.com/Quick/Quick

import XCTest
import Quick
import Nimble
import Iris

struct TestOperation: ReadOperation, WriteOperation, PostOperation, IndirectModelOperation {

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
//
//    struct Response: Decodable {
//        var success: String
//    }

    typealias RequestType = Request
    typealias ResponseType = String

    var headers: [String: String] { [:] }

        var url: String { "https://reqbin.com/echo/post/json" }
//    var url: String { "https://google.ru" }
    //    var url: String { "https://exampleqqq.com" }

    var request: Request {
        Request()
    }

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
                let flow = transport.execute(TestOperation())

                waitUntil(timeout: .seconds(6)) { done in

                    DispatchQueue.global().async {
                        Thread.sleep(forTimeInterval: 5)

                        expect(flow.result.map { $0^ }).to(beSuccess { value in
                            expect(value).to(equal("true"))
                        })

                        done()
                    }
                }
            }
        }
    }
}

postfix operator ^

import PromiseKit
public extension PromiseKit.Result {
    static postfix func ^ (lhs: Self) -> Swift.Result<T, Error> {
        switch lhs {
            case .fulfilled(let value):
                return .success(value)
            case .rejected(let error):
                return .failure(error)
        }
    }
}

