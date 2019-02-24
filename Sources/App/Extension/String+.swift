//
//  String+.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

extension String {

    var urlFirstComponent: String? {
        guard let endIndex = range(of: "/")?.lowerBound else {
            return nil
        }

        return String(self[...index(before: endIndex)])
    }

    var urlLastComponent: String? {
        guard let startIndex = range(of: "/", options: .backwards)?.upperBound else {
            return nil
        }

        if let range = range(of: "?", options: .backwards) {
            let endIndex = index(before: range.lowerBound)
            return String(self[startIndex...endIndex])
        } else {
            return String(self[startIndex...])
        }
    }

    var urlPath: String? {
        if let range = range(of: "?", options: .backwards) {
            let endIndex = index(before: range.lowerBound)
            return String(self[...endIndex])
        } else {
            return self
        }
    }

    var urlParameters: [String: String] {
        var result: [String: String] = [:]

        if let range = range(of: "?") {
            let parameters = String(self[range.upperBound...]).components(separatedBy: "&")
            for parameter in parameters {
                let items = parameter.components(separatedBy: "=")
                if items.count == 2 {
                    let name = items[0]
                    let value = items[1]
                    result[name] = value
                }
            }

            return result
        } else {
            return result
        }
    }

    func appendURL(parameter: String, value: String) -> String {
        let parameterString = "\(parameter)=\(value)"
        if range(of: "?") == nil {
            return self + "?" + parameterString
        } else {
            return self + "&" + parameterString
        }
    }
}
