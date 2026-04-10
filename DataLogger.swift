import Foundation
import UIKit

class DataLogger {
    
    private let fileName = "agv_log.csv"
    private var fileURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }
    
    init() {
        createCSVHeaderIfNeeded()
    }
    
    private func createCSVHeaderIfNeeded() {
        guard let url = fileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        let header = "timestamp_iso8601,agv_id,load_flag,confidence,change_ratio,coord_x,coord_y\n"
        try? header.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func log(agvId: String, isLoaded: Bool, confidence: Float, ratio: Float, x: Double, y: Double) {
        guard let url = fileURL else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp),\(agvId),\(isLoaded ? 1 : 0),\(String(format: "%.2f", confidence)),\(String(format: "%.4f", ratio)),\(String(format: "%.2f", x)),\(String(format: "%.2f", y))\n"
        
        if let data = line.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    func clearData() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
        createCSVHeaderIfNeeded()
    }
    
    func getExportURL() -> URL? {
        return fileURL
    }
}
