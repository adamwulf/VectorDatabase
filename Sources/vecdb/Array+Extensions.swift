//
//  Array+Extensions.swift
//  vecdb
//
//  Created by Adam Wulf on 6/4/24.
//

import Foundation

extension Array where Element == Double {
    static func -(lhs: [Double], rhs: [Double]) -> [Double] {
        let minCount = Swift.min(lhs.count, rhs.count)
        var result = [Double]()
        for i in 0..<minCount {
            result.append(lhs[i] - rhs[i])
        }
        return result
    }
    static func +(lhs: [Double], rhs: [Double]) -> [Double] {
        let minCount = Swift.min(lhs.count, rhs.count)
        var result = [Double]()
        for i in 0..<minCount {
            result.append(lhs[i] + rhs[i])
        }
        return result
    }
}
