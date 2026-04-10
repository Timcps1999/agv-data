import Foundation
import CoreMotion

class MotionManager {
    private let motion = CMMotionManager()
    
    // Current coordinates
    private(set) var currentX: Double = 0.0
    private(set) var currentY: Double = 0.0
    
    // Cumulative velocity (used to estimate displacement)
    private var velocityX: Double = 0.0
    private var velocityY: Double = 0.0
    
    func startTracking() {
        guard motion.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        
        motion.deviceMotionUpdateInterval = 0.1 // 10Hz
        motion.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            
            // Use UserAcceleration (acceleration minus gravity)
            let accel = data.userAcceleration
            let dt = 0.1
            
            // Basic integration (Note: constant drift is expected)
            // v = u + at
            self.velocityX += accel.x * 9.81 * dt
            self.velocityY += accel.y * 9.81 * dt
            
            // s = s0 + vt
            self.currentX += self.velocityX * dt
            self.currentY += self.velocityY * dt
        }
    }
    
    func resetOrigin() {
        currentX = 0.0
        currentY = 0.0
        velocityX = 0.0
        velocityY = 0.0
    }
    
    func stopTracking() {
        motion.stopDeviceMotionUpdates()
    }
}
