//
//  OpenBeautyFactsServiceTests.swift
//  SkincareCompanionTests
//
//  Exercises OpenBeautyFactsService against a mock that conforms to
//  URLSessionProtocol, so these tests run offline and deterministically
//  rather than depending on the real API being up.
//

import XCTest
@testable import SkincareCompanion

final class MockURLSession: URLSessionProtocol {
    var nextData: Data?
    var nextStatusCode: Int = 200
    var nextError: Error?
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = nextError { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: nextStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (nextData ?? Data(), response)
    }
}

final class OpenBeautyFactsServiceTests: XCTestCase {

    func test_searchProducts_parsesValidResponse() async throws {
        let mock = MockURLSession()
        mock.nextData = """
        {
          "products": [
            {
              "code": "1234567890123",
              "product_name": "Hydrating Serum",
              "brands": "Test Brand",
              "ingredients_text": "Water, Hyaluronic Acid, Niacinamide",
              "categories_tags": ["en:skin-care", "en:serums"],
              "image_url": "https://example.com/image.jpg"
            }
          ]
        }
        """.data(using: .utf8)

        let service = OpenBeautyFactsService(session: mock)
        let products = try await service.searchProducts(matching: "hydrating serum")

        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.name, "Hydrating Serum")
        XCTAssertEqual(products.first?.category, .serum)
        XCTAssertTrue(products.first?.detectedActives.contains(.hyaluronicAcid) ?? false)
    }

    func test_searchProducts_skipsEntriesMissingAName() async throws {
        let mock = MockURLSession()
        mock.nextData = """
        { "products": [ { "code": "111", "brands": "No Name Brand" } ] }
        """.data(using: .utf8)

        let service = OpenBeautyFactsService(session: mock)
        let products = try await service.searchProducts(matching: "anything")

        XCTAssertTrue(products.isEmpty)
    }

    func test_searchProducts_throwsOnBadStatusCode() async {
        let mock = MockURLSession()
        mock.nextStatusCode = 500
        mock.nextData = Data()

        let service = OpenBeautyFactsService(session: mock)

        do {
            _ = try await service.searchProducts(matching: "anything")
            XCTFail("Expected an error to be thrown")
        } catch let error as NetworkError {
            if case .badStatusCode(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected badStatusCode, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_fetchProduct_throwsNotFound_whenProductMissing() async {
        let mock = MockURLSession()
        mock.nextData = """
        { "status": 0, "product": null }
        """.data(using: .utf8)

        let service = OpenBeautyFactsService(session: mock)

        do {
            _ = try await service.fetchProduct(barcode: "000")
            XCTFail("Expected .notFound to be thrown")
        } catch NetworkError.notFound {
            // expected
        } catch {
            XCTFail("Expected NetworkError.notFound, got \(error)")
        }
    }

    func test_searchProducts_sendsUserAgentHeader() async throws {
        let mock = MockURLSession()
        mock.nextData = "{ \"products\": [] }".data(using: .utf8)

        let service = OpenBeautyFactsService(session: mock)
        _ = try await service.searchProducts(matching: "cleanser")

        XCTAssertNotNil(mock.lastRequest?.value(forHTTPHeaderField: "User-Agent"))
    }
}
