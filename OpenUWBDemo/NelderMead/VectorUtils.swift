/*
 Copyright © 2023 Gunnar Beutner,
 Copyright © 2019 Jon Tingvold

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

func sum<T: Numeric>(_ vectors: [Vector<T>]) -> Vector<T> {
    let p = vectors[0].dimensions
    let zeros = Vector(repeatedValue: T.zero, dimensions: p)
    
    let sum = vectors.reduce(zeros, { partial_sum, vector in
        
        guard vector.dimensions == p else {
            fatalError("Vectors must be of same length")
        }
        
        return partial_sum + vector
    })
    
    return sum
}

func mean<T: BinaryFloatingPoint>(_ vectors: [Vector<T>]) -> Vector<T> {
    let sum_ = sum(vectors)
    let count = T(vectors.count)
    let average = (1/count) * sum_
    return average
}
