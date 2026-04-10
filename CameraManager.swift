import AVFoundation
import UIKit

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.agv.camera.queue")
    
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?
    
    func setupSession(completion: @escaping (Bool) -> Void) {
        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                completion(false)
                return
            }
            
            if self.session.canAddInput(input) { self.session.addInput(input) }
            
            self.output.setSampleBufferDelegate(self, queue: self.queue)
            self.output.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
            
            // Lock Exposure and Focus for stability
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            
            self.session.commitConfiguration()
            self.session.startRunning()
            completion(true)
        }
    }
    
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
