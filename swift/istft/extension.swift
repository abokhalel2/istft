//
//  ArrayMatrixExtensions.swift
//  RosaKit
//
//  Created by Hrebeniuk Dmytro on 20.12.2019.
//  Copyright © 2019 Dmytro Hrebeniuk. All rights reserved.
//

import Foundation
import Accelerate

public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == [Double] {
 
    public var transposed: [[Double]] {
        let matrix = self
        let newMatrixCols = matrix.count
        let newMatrixRows = matrix.first?.count ?? 1
        
        var results = [Double](repeating: 0.0, count: newMatrixCols*newMatrixRows)

        vDSP_mtransD(matrix.flatMap { $0 }, 1, &results, 1, vDSP_Length(newMatrixRows), vDSP_Length(newMatrixCols))
        
        return results.chunked(into: newMatrixCols)
    }
}

extension Collection where Iterator.Element == Double {
    var convertToFloat: [Float] {
        return compactMap{ Float($0) }
    }
}

extension Collection where Iterator.Element == Float {
    var convertToDouble: [Double] {
        return compactMap{ Double($0) }
    }
}
