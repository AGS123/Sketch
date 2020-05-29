//
//  SketchToolType.swift
//  Sketch
//
//  Created by daihase on 04/06/2018.
//  Copyright (c) 2018 daihase. All rights reserved.
//

import UIKit

public enum SketchToolType {
    case pen
    case eraser
    case stamp
    case line
    case arrow
    case rectangleStroke
    case rectangleFill
    case ellipseStroke
    case ellipseFill
    case star
    case fill
}

public enum ImageRenderingMode {
    case scale
    case original
}

public protocol SketchViewDelegate: class  {
    func drawView(_ view: SketchView, willBeginDrawingUsingTool tool: SketchTool, position point: CGPoint)
    func drawView(_ view: SketchView, didContinueDrawingUsingTool tool: SketchTool, position point: CGPoint)
    func drawView(_ view: SketchView, didEndDrawingUsingTool tool: SketchTool)
}

public class SketchView: UIView {
    public var lineSnapping = CGFloat(8)
    public var lineColor = UIColor.black
    public var lineWidth = CGFloat(10)
    public var lineAlpha = CGFloat(1)
    public var stampImage: UIImage?
    public var drawTool: SketchToolType = .pen
    public var drawingPenType: PenType = .normal
    public var sketchViewDelegate: SketchViewDelegate?
    private var currentTool: SketchTool?
    private let pathArray: NSMutableArray = NSMutableArray()
    private let bufferArray: NSMutableArray = NSMutableArray()
    private var currentPoint: CGPoint?
    private var previousPoint1: CGPoint?
    private var previousPoint2: CGPoint?
    private var image: UIImage?
    private var backgroundImage: UIImage?
    private var drawMode: ImageRenderingMode = .original
    private var touchesEnded = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        prepareForInitial()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        prepareForInitial()
    }

    private func prepareForInitial() {
        backgroundColor = UIColor.clear
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        switch drawMode {
        case .original:
            image?.draw(at: CGPoint.zero)
            break
        case .scale:
            image?.draw(in: self.bounds)
            break
        }

        currentTool?.draw()
    }

    private func updateCacheImage(_ isUpdate: Bool) {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)

        if isUpdate {
            image = nil
            switch drawMode {
            case .original:
                if let backgroundImage = backgroundImage  {
                    (backgroundImage.copy() as! UIImage).draw(at: CGPoint.zero)
                }
                break
            case .scale:
                if let backgroundImage = backgroundImage  {
                    (backgroundImage.copy() as! UIImage).draw(in: self.bounds)
                }
                break
            }

            for obj in pathArray {
                if let tool = obj as? SketchTool {
                    tool.draw()
                }
            }
        } else {
            switch drawMode {
            case .original:
                image?.draw(at: .zero)
              case .scale:
                image?.draw(in: self.bounds)
            }
            currentTool?.draw()
        }
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    private func toolWithCurrentSettings() -> SketchTool? {
        switch drawTool {
        case .pen:
            return PenTool()
        case .eraser:
            return EraserTool()
        case .stamp:
            return StampTool()
        case .line:
            return LineTool()
        case .arrow:
            return ArrowTool()
        case .rectangleStroke:
            let rectTool = RectTool()
            rectTool.isFill = false
            return rectTool
        case .rectangleFill:
            let rectTool = RectTool()
            rectTool.isFill = true
            return rectTool
        case .ellipseStroke:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = false
            return ellipseTool
        case .ellipseFill:
            let ellipseTool = EllipseTool()
            ellipseTool.isFill = true
            return ellipseTool
        case .star:
            return StarTool()
        case .fill:
            return FillTool()
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if currentTool != nil {
            finishDrawing()
        }

        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)
        currentTool = toolWithCurrentSettings()
        currentTool?.lineWidth = lineWidth
        currentTool?.lineColor = lineColor
        currentTool?.lineAlpha = lineAlpha

        if let point = snappingPoint() {
            previousPoint1 = point
            currentPoint = point
        }
        
        if let tool = currentTool, let point = currentPoint {
            sketchViewDelegate?.drawView(self, willBeginDrawingUsingTool: tool, position: point)
        }
        
        switch currentTool! {
        case is PenTool:
            guard let penTool = currentTool as? PenTool else { return }
            pathArray.add(penTool)
            penTool.drawingPenType = drawingPenType
            penTool.setInitialPoint(currentPoint!)
        case is StampTool:
            guard let stampTool = currentTool as? StampTool else { return }
            pathArray.add(stampTool)
            stampTool.setStampImage(image: stampImage)
            stampTool.setInitialPoint(currentPoint!)
        default:
            guard let currentTool = currentTool else { return }
            pathArray.add(currentTool)
            currentTool.setInitialPoint(currentPoint!)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        previousPoint2 = previousPoint1
        previousPoint1 = touch.previousLocation(in: self)
        currentPoint = touch.location(in: self)

        if touchesEnded, let point = snappingPoint() {
            previousPoint1 = point
            currentPoint = point
        }
        
        if let penTool = currentTool as? PenTool {
            let renderingBox = penTool.createBezierRenderingBox(previousPoint2!, widhPreviousPoint: previousPoint1!, withCurrentPoint: currentPoint!)
            setNeedsDisplay(renderingBox)
        } else {
            currentTool?.moveFromPoint(previousPoint1!, toPoint: currentPoint!)
            setNeedsDisplay()
        }
        
        if let tool = currentTool, let point = currentPoint {
            sketchViewDelegate?.drawView(self, didContinueDrawingUsingTool: tool, position: point)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded = true
        touchesMoved(touches, with: event)
        touchesEnded = false
        finishDrawing()
    }

    fileprivate func finishDrawing() {
        updateCacheImage(false)
        bufferArray.removeAllObjects()
        if let tool = currentTool {
            sketchViewDelegate?.drawView(self, didEndDrawingUsingTool: tool)
        }
        currentTool = nil
    }

    private func resetTool() {
        currentTool = nil
    }

    public func clear() {
        resetTool()
        bufferArray.removeAllObjects()
        pathArray.removeAllObjects()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    func pinch() {
        resetTool()
        guard let tool = pathArray.lastObject as? SketchTool else { return }
        bufferArray.add(tool)
        pathArray.removeLastObject()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    public func loadImage(image: UIImage, drawMode: ImageRenderingMode = .original) {
        self.image = image
        self.drawMode = drawMode
        backgroundImage =  image.copy() as? UIImage
        bufferArray.removeAllObjects()
        pathArray.removeAllObjects()
        updateCacheImage(true)

        setNeedsDisplay()
    }

    public func undo() {
        if canUndo() {
            guard let tool = pathArray.lastObject as? SketchTool else { return }
            resetTool()
            bufferArray.add(tool)
            pathArray.removeLastObject()
            updateCacheImage(true)

            setNeedsDisplay()
        }
    }

    public func redo() {
        if canRedo() {
            guard let tool = bufferArray.lastObject as? SketchTool else { return }
            resetTool()
            pathArray.add(tool)
            bufferArray.removeLastObject()
            updateCacheImage(true)

            setNeedsDisplay()
        }
    }

    public func canUndo() -> Bool {
        return pathArray.count > 0
    }

    public func canRedo() -> Bool {
        return bufferArray.count > 0
    }
    
    public func saveImage() -> UIImage? {
        return image
    }
    
    private func snappingPoint() -> CGPoint? {
        if let currentTool = currentTool as? LineTool, let point = currentPoint {
            for path in pathArray {
                if let tool = path as? LineTool {
                    guard tool != currentTool else {
                        return nil
                    }
                    if point.distance(tool.firstPoint) <= lineSnapping {
                        return tool.firstPoint
                    } else if point.distance(tool.lastPoint) <= lineSnapping {
                        return tool.lastPoint
                    }
                }
            }
        }
        return nil
    }
}

func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
    return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
}

func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
    return sqrt(CGPointDistanceSquared(from: from, to: to))
}

extension CGPoint {
    func distance(_ point: CGPoint) -> CGFloat {
        return CGPointDistance(from: self, to: point)
    }
}
