import XCTest
import PromiseKit


class TestNSURLConnectionPlusPromise: XCTestCase {

    func resource(fn: String, ext: String = "json") -> NSURLRequest {
        let url = NSBundle(forClass:self.classForCoder).pathForResource(fn, ofType:ext);
        return NSURLRequest(URL:NSURL(string:"file://\(url)"))
    }

    var plainText: NSURLRequest { return resource("plain", ext: "text") }
    var dictionaryJSON: NSURLRequest { return resource("dictionary") }
    var arrayJSON: NSURLRequest { return resource("array") }


    func test_001() {
        let e1 = expectationWithDescription("foo189234")
        NSURLConnection.promise(dictionaryJSON).then { (json:Dictionary<String, Any>) -> Int in
            let hi:Any = json["data"]!
            XCTAssertEqualObjects(hi as String, "hi")
            return 1
        }.catch { (err:NSError) in
            return 3
        }.then { (value:Int) -> Void in
            XCTAssertEqual(value, 1)
            e1.fulfill()
        }
        waitForExpectationsWithTimeout(1000, handler: nil)
    }

    func test_002() {
        let e1 = expectationWithDescription("")
        NSURLConnection.promise(plainText).then { (json:Dictionary<String, Any>) -> Int in
            XCTFail()
            return 1
        }.catch { (err:NSError) -> Int in
            XCTAssertEqualObjects(err.domain, NSCocoaErrorDomain)
            XCTAssertEqualObjects(err.code, 3840)
            return 1234
        }.then { (value:Int) -> Void in
            XCTAssertEqual(value, 1234)
            e1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func test_003() {
        let e1 = expectationWithDescription("")
        NSURLConnection.promise(dictionaryJSON).then { (json:Any[]) -> Int in
            XCTFail()
            return 1
        }.catch { (err:NSError) -> Int in
            XCTAssertEqualObjects(err.domain, PMKErrorDomain)
            XCTAssertEqualObjects(err.code, PMKJSONErrorCode)
            XCTAssertEqualObjects(err.userInfo[PMKJSONErrorJSONObjectKey] as NSDictionary, ["data": "hi"])
            return 1234
        }.then { (value:Int) -> Void in
            XCTAssertEqual(value, 1234)
            e1.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }

    func test_004() {
        let e1 = expectationWithDescription("")
        NSURLConnection.promise(arrayJSON).then { (json:Any[]) -> Int in
            let hi:Any = json[1]
            XCTAssertEqualObjects(hi as String, "hi")
            e1.fulfill()
            return 1
        }
        waitForExpectationsWithTimeout(1, handler: nil)
    }
}
