/*
 Copyright © 2023 Gunnar Beutner.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import OpenUWB

class IndoorLocationModel : Optimizable {
    var minInitSolution: Vector<Double>
    var maxInitSolution: Vector<Double>
    
    private var floor: Floor
    private var accessories: [String: Accessory]
    private var distances: [String: Float] = [:]
    public var probes: [[Double]: Double] = [:]
    
    init(floorplan: Floorplan, distances: [String: Float]) {
        self.floor = floorplan.floors[0]
        self.minInitSolution = Vector<Double>(floor.bounds[0])
        self.maxInitSolution = Vector<Double>(floor.bounds[1])
        self.accessories = Dictionary(uniqueKeysWithValues: floorplan.accessories.map { ($0.id, $0) })
        var nonExactCount = 0
        self.distances = distances.filter {
            if accessories[$0.key]!.exact {
                return true
            }
            nonExactCount += 1
            return nonExactCount <= 3
        }
    }
    
    private func dist(_ a: Vector<Double>, _ b: Vector<Double>) -> Double {
        return sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2) + pow(a[2] - b[2], 2))
    }
    
    func testCost(solution: Vector<Double>) -> Double {
        let lowerBound = self.floor.bounds
        guard solution[0] >= self.floor.bounds[0][0], solution[0] <= self.floor.bounds[1][0],
              solution[1] >= self.floor.bounds[0][1], solution[1] <= self.floor.bounds[1][1],
              solution[2] >= self.floor.bounds[0][2], solution[2] <= self.floor.bounds[1][2]
        else { return Double.infinity }

        //guard solution[2] > 0.5, solution[2] < 1.5
        //else { return Double.infinity }

        var valuesExact: [Double] = []
        var valuesInexact: [Double] = []
        for (id, accessory) in self.accessories {
            let nodeLocation = Vector<Double>(accessory.location)
            let targetDistance = dist(nodeLocation, solution)
            if let distance = distances[id] {
                let error = min(targetDistance - Double(distance), 7.5)
                if accessory.exact {
                    valuesExact.append(pow(error, 2))
                } else {
                    valuesInexact.append(pow(error, 2))
                }
            }
        }
        var res: Double
        if valuesExact.count > 2 {
            res = mean(valuesExact)
        } else {
            res = mean(valuesExact) * 10 + mean(valuesInexact)
        }
        self.probes[solution.vector] = res
        return res
    }
}

struct FloorplanView: View {
    @ObservedObject var floorplanManager: FloorplanManager
    var distances: [String: Float] = [:]
    var ourLocation: Vector<Double>?
    var bestError: Double?
    var probes: [[Double]: Double]?

    var body: some View {
        VStack {
            if let location = self.ourLocation {
                Text(String(format: "%0.2f %0.2f %0.2f", location[0], location[1], location[2]))
            }
            ZStack {
                Canvas { context, size in
                    let floor = self.floorplanManager.floorplan.floors[0]
                    let xScale = 0.97 * 300 / floor.bounds[1][0], yScale = 0.97 * 300 / floor.bounds[1][1]
                    //CGAffineTransformMakeScale(1, -1),
                    context.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 5, 5)
                    for room in floor.rooms {
                        let path = CGMutablePath()
                        path.addLines(between: room.points.map {
                            CGPoint(x: $0[0] * xScale, y: (floor.bounds[1][1] - $0[1]) * yScale)
                        })
                        path.closeSubpath()
                        
                        context.stroke(
                            Path(path),
                            with: .color(.green),
                            lineWidth: 1)
                    }
                    for accessory in self.floorplanManager.floorplan.accessories {
                        context.stroke(
                            Path(ellipseIn: CGRect(x: accessory.location[0] * xScale, y: (floor.bounds[1][1] - accessory.location[1]) * yScale, width: 2, height: 2)),
                            with: distances[accessory.id] != nil ? .color(.red) : .color(.gray),
                            lineWidth: 4)
                        if let distance = distances[accessory.id] {
                            let width = Double(distance) * xScale
                            let height = Double(distance) * yScale
                            let rect = CGRect(x: accessory.location[0] * xScale - width, y: (floor.bounds[1][1] - accessory.location[1]) * yScale - height, width: 2 * width, height: 2 * height)
                            context.stroke(
                                Path(ellipseIn: rect),
                                with: accessory.exact ? .color(.orange) : .color(.gray),
                                lineWidth: 1)
                        }
                    }
                    
                    if let probes = self.probes {
                        for (solution, _) in probes {
                            context.stroke(
                                Path(ellipseIn: CGRect(x: solution[0] * xScale, y: (floor.bounds[1][1] - solution[1]) * yScale, width: 0.5, height: 0.5)),
                                with: .color(.mint),
                                lineWidth: 1)
                        }
                    }
                    
                    if let location = self.ourLocation {
                        context.stroke(
                            Path(ellipseIn: CGRect(x: location[0] * xScale, y: (floor.bounds[1][1] - location[1]) * yScale, width: 2, height: 2)),
                            with: .color(.purple),
                            lineWidth: 4)
                    }
                }
                .frame(width: 300, height: 300, alignment: .center)
                .border(Color.blue)
                .padding(CGFloat(10))
            }
        }
    }
    
    init(floorplanManager: FloorplanManager, distances: [String: Float], ourLocation: Vector<Double>?, bestError: Double?, probes: [[Double]: Double]?) {
        self.floorplanManager = floorplanManager
        self.distances = distances
        self.ourLocation = ourLocation
        self.bestError = bestError
        self.probes = probes
    }
}

class FloorplanManager: ObservableObject {
    public private(set) var floorplan: Floorplan
    
    init() {
        let asset = NSDataAsset(name: "Floorplan")
        self.floorplan = loadFloorplan(asset!.data)
    }
}

struct FloorplanView_Previews: PreviewProvider {
    static var previews: some View {
        FloorplanView(floorplanManager: FloorplanManager(), distances: [:], ourLocation: nil, bestError: nil, probes: nil)
    }
}
