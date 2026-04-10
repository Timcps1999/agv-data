import UIKit
import Accelerate

class LoadDetector {
    
    // MARK: - Configuration Constraints
    // Adjust these to tune detection for your environment
    private let regionOfInterest = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4) // Center area
    private let pixelDiffThreshold: UInt8 = 35  // Minimum change in pixel value (0-255)
    private let changeRatioThreshold: Float = 0.08 // 8% of ROI must change to be LOAD
    private let smoothingWindowSize = 5         // Majority vote buffer size
    
    private var previousROIBuffer: [UInt8]?
    private var smoothingBuffer: [Bool] = []
    
    struct DetectionResult {
        let isLoaded: Bool
        let confidence: Float
        let changeRatio: Float
    }
    
    /// Processes a pixel buffer and returns load status
    func detect(pixelBuffer: CVPixelBuffer) -> DetectionResult? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Use the Y (luminance) plane for grayscale processing
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        
        // Calculate ROI in pixel coordinates
        let roiX = Int(regionOfInterest.origin.x * CGFloat(width))
        let roiY = Int(regionOfInterest.origin.y * CGFloat(height))
        let roiW = Int(regionOfInterest.size.width * CGFloat(width))
        let roiH = Int(regionOfInterest.size.height * CGFloat(height))
        
        // Extract ROI pixels
        var currentROI = [UInt8](<repeating: 0, count: roiW * roiH>)
        for y in 0..<roiH {
            let srcOffset = (roiY + y) * bytesPerRow + roiX
            let dstOffset = y * roiW
            let srcPtr = baseAddress.advanced(by: srcOffset).assumingMemoryBound(to: UInt8.self)
            currentROI.withUnsafeMutableBufferPointer { buffer in
                memcpy(buffer.baseAddress!.advanced(by: dstOffset), srcPtr, roiW)
            }
        }
        
        guard let previousROI = previousROIBuffer else {
            previousROIBuffer = currentROI
            return nil // Need second frame to compare
        }
        
        // Frame Differencing
        var diffCount = 0
        for i in 0..<currentROI.count {
            let diff = abs(Int(currentROI[i]) - Int(previousROI[i]))
            if diff > pixelDiffThreshold {
                diffCount += 1
            }
        }
        
        let changeRatio = Float(diffCount) / Float(roiW * roiH)
        let rawIsLoaded = changeRatio > changeRatioThreshold
        
        // Temporal Smoothing (Majority Vote)
        smoothingBuffer.append(rawIsLoaded)
        if smoothingBuffer.count > smoothingWindowSize {
            smoothingBuffer.removeFirst()
        }
        
        let loadCount = smoothingBuffer.filter { $0 }.count
        let smoothIsLoaded = loadCount > (smoothingBuffer.count / 2)
        
        // Confidence calculation based on how definitive the change ratio is
        let confidence = min(1.0, changeRatio / (changeRatioThreshold * 2))
        
        previousROIBuffer = currentROI
        
        return DetectionResult(isLoaded: smoothIsLoaded, confidence: confidence, changeRatio: changeRatio)
    }
    
    func reset() {
        previousROIBuffer = nil
        smoothingBuffer.removeAll()
    }
}
