//
//  MultiStrokeRecognizer.swift
//  GestureCalculator
//
//  Created by Bindita Chaudhuri on 10/23/18.
//  Copyright © 2018 Bindita Chaudhuri. All rights reserved.
//
// Source: https://github.com/fe9lix/PennyPincher
//

import Foundation

import UIKit
import UIKit.UIGestureRecognizerSubclass

public struct PennyPincherTemplate {
    public let id: String
    public let points: [CGPoint]
}

public class MultiStrokeRecognizer: UIGestureRecognizer {
    public var enableMultipleStrokes: Bool = true
    public var allowedTimeBetweenMultipleStrokes: TimeInterval = 0.2
    public var templates = [PennyPincherTemplate]()
    
    private(set) public var result: (template: PennyPincherTemplate, similarity: CGFloat)?
    
    private(set) var pennyPincher = PennyPincher()
    private(set) var points = [CGPoint]()
    private(set) var timer: Timer?
    
    public override func reset() {
        super.reset()
        invalidateTimer()
        points.removeAll(keepingCapacity: false)
        result = nil
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        invalidateTimer()
        if let touch = touches.first {
            points.append(touch.location(in: view))
        }
        if state == .possible {
            state = .began
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            points.append(touch.location(in: view))
        }
        state = .changed
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if enableMultipleStrokes {
            timer = Timer.scheduledTimer(timeInterval: allowedTimeBetweenMultipleStrokes, target: self, selector: #selector(timerDidFire(_:)), userInfo: nil, repeats: false)
        } else {
            recognize()
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        points.removeAll(keepingCapacity: false)
        state = .cancelled
    }
    
    private func recognize() {
        result = PennyPincher.recognize(points, templates: templates)
        state = result != nil ? .ended : .failed
    }
    
    @objc private func timerDidFire(_ timer: Timer) {
        recognize()
    }
    
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}

public typealias PennyPincherResult = (template: PennyPincherTemplate, similarity: CGFloat)

public class PennyPincher {
    private static let NumResamplingPoints = 16
    
    public class func createTemplate(_ id: String, points: [CGPoint]) -> PennyPincherTemplate? {
        guard points.count > 0 else { return nil }
        
        return PennyPincherTemplate(id: id, points: PennyPincher.resampleBetweenPoints(points))
    }
    
    public class func recognize(_ points: [CGPoint], templates: [PennyPincherTemplate]) -> PennyPincherResult? {
        guard points.count > 0 && templates.count > 0 else { return nil }
        
        let c = PennyPincher.resampleBetweenPoints(points)
        
        guard c.count > 0 else { return nil }
        
        var similarity = CGFloat.leastNormalMagnitude
        var t: PennyPincherTemplate!
        var d: CGFloat
        
        for template in templates {
            d = 0.0
            
            let count = min(c.count, template.points.count)
            
            for i in 0...count - 1 {
                let tp = template.points[i]
                let cp = c[i]
                
                d = d + tp.x * cp.x + tp.y * cp.y
                
                if d > similarity {
                    similarity = d
                    t = template
                }
            }
        }
        
        guard t != nil else { return nil }
        
        return (t, similarity)
    }
    
    private class func resampleBetweenPoints(_ p: [CGPoint]) -> [CGPoint] {
        var points = p
        let i = pathLength(points) / CGFloat(PennyPincher.NumResamplingPoints - 1)
        var d: CGFloat = 0.0
        var v = [CGPoint]()
        var prev = points.first!
        var index = 0
        
        for _ in points {
            if index == 0 {
                index += 1
                continue
            }
            let thisPoint = points[index]
            let prevPoint = points[index - 1]
            let pd = distanceBetween(thisPoint, to: prevPoint)
            
            if (d + pd) >= i {
                let q = CGPoint(
                    x: prevPoint.x + (thisPoint.x - prevPoint.x) * (i - d) / pd,
                    y: prevPoint.y + (thisPoint.y - prevPoint.y) * (i - d) / pd
                )
                var r = CGPoint(x: q.x - prev.x, y: q.y - prev.y)
                let rd = distanceBetween(CGPoint.zero, to: r)
                r.x = r.x / rd
                r.y = r.y / rd
                d = 0.0
                prev = q
                v.append(r)
                points.insert(q, at: index)
                index += 1
            } else {
                d = d + pd
            }
            index += 1
        }
        return v
    }
    
    private class func pathLength(_ points: [CGPoint]) -> CGFloat {
        var d: CGFloat = 0.0
        for i in 1..<points.count {
            d = d + distanceBetween(points[i - 1], to: points[i])
        }
        return d
    }
    
    private class func distanceBetween(_ pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        let distX = pointA.x - pointB.x
        let distY = pointA.y - pointB.y        
        return sqrt((distX * distX) + (distY * distY))
    }
}
