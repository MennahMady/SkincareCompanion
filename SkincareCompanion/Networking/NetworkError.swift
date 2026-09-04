//
//  NetworkError.swift
//  SkincareCompanion
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case badStatusCode(Int)
    case decodingFailed(underlying: Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That request couldn't be built. Please try again."
        case .requestFailed:
            return "Couldn't reach the product database. Check your connection and try again."
        case .badStatusCode(let code):
            return "The product database returned an unexpected response (\(code))."
        case .decodingFailed:
            return "Got a response we couldn't understand from the product database."
        case .notFound:
            return "No product found for that barcode."
        }
    }
}
