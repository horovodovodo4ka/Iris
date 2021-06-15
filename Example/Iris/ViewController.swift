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

        transport.execute(TestOperation())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension TransportConfig {
    static let `default` = TransportConfig(printer: AstarothPrinter(), encoder: jsonEncoder, decoder: jsonDecoder)
}

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

//    var url: String { "https://reqbin.com/echo/post/json" }
    var url: String { "https://google.ru" }

    var request: Request {
        Request()
    }
}
