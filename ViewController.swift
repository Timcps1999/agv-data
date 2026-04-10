import UIKit

class ViewController: UIViewController {

    private let cameraManager = CameraManager()
    private let detector = LoadDetector()
    private let logger = DataLogger()
    private let motionManager = MotionManager()
    
    private var isRecording = false
    private var samplingTimer: Timer?
    private var latestBuffer: CVPixelBuffer?
    private var selectedInterval: Double = 1.0
    
    // UI Elements
    private let previewContainer = UIView()
    private let statusLabel = UILabel()
    private let resultLabel = UILabel()
    private let coordLabel = UILabel()
    private let agvIdField = UITextField()
    private let intervalPicker = UISegmentedControl(items: ["1s", "2s", "5s", "10s"])
    private let startBtn = UIButton(type: .system)
    private let stopBtn = UIButton(type: .system)
    private let resetOriginBtn = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        motionManager.startTracking()
        
        cameraManager.setupSession { success in
            if success {
                DispatchQueue.main.async {
                    let layer = self.cameraManager.createPreviewLayer()
                    layer.frame = self.previewContainer.bounds
                    self.previewContainer.layer.addSublayer(layer)
                }
            }
        }
        
        cameraManager.onFrameCaptured = { [weak self] buffer in
            self?.latestBuffer = buffer
        }
    }

    private func setupUI() {
        view.backgroundColor = .black
        
        // Layout constants
        let padding: CGFloat = 20
        
        // 1. Camera Preview
        previewContainer.frame = view.bounds
        view.addSubview(previewContainer)
        
        // 2. Translucent Overlay for Controls
        let overlay = UIView(frame: CGRect(x: 0, y: view.frame.height - 400, width: view.frame.width, height: 400))
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(overlay)
        
        // 3. Status Labels
        statusLabel.text = "STATUS: STOPPED"
        statusLabel.textColor = .white
        statusLabel.font = .boldSystemFont(ofSize: 18)
        statusLabel.frame = CGRect(x: padding, y: 20, width: 200, height: 30)
        overlay.addSubview(statusLabel)
        
        resultLabel.text = "DETECTION: ---"
        resultLabel.textColor = .yellow
        resultLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        resultLabel.frame = CGRect(x: padding, y: 50, width: 350, height: 30)
        overlay.addSubview(resultLabel)
        
        // 4. Coordinates Label
        coordLabel.text = "COORD: X: 0.00, Y: 0.00"
        coordLabel.textColor = .cyan
        coordLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        coordLabel.frame = CGRect(x: padding, y: 80, width: 300, height: 30)
        overlay.addSubview(coordLabel)
        
        // 5. AGV ID Field & Interval Picker
        agvIdField.placeholder = "AGV_ID"
        agvIdField.text = "AGV_01"
        agvIdField.backgroundColor = .white
        agvIdField.borderStyle = .roundedRect
        agvIdField.frame = CGRect(x: padding, y: 120, width: 150, height: 35)
        overlay.addSubview(agvIdField)
        
        intervalPicker.selectedSegmentIndex = 0
        intervalPicker.addTarget(self, action: #selector(intervalChanged), for: .valueChanged)
        intervalPicker.frame = CGRect(x: padding + 170, y: 120, width: 180, height: 35)
        overlay.addSubview(intervalPicker)
        
        // 6. Buttons
        setupButton(startBtn, title: "START RECORDING", color: .systemGreen, y: 170)
        setupButton(stopBtn, title: "STOP RECORDING", color: .systemRed, y: 220)
        
        setupButton(resetOriginBtn, title: "SET ORIGIN (0,0)", color: .systemPurple, y: 20, x: view.frame.width - 160, width: 140)
        resetOriginBtn.addTarget(self, action: #selector(handleResetOrigin), for: .touchUpInside)
        overlay.addSubview(resetOriginBtn)
        
        let clearBtn = UIButton(type: .system)
        setupButton(clearBtn, title: "CLEAR DATA", color: .gray, y: 270, width: 170)
        
        let exportBtn = UIButton(type: .system)
        setupButton(exportBtn, title: "EXPORT CSV", color: .systemBlue, y: 270, x: padding + 180, width: 170)
        
        startBtn.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        stopBtn.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        clearBtn.addTarget(self, action: #selector(handleClear), for: .touchUpInside)
        exportBtn.addTarget(self, action: #selector(handleExport), for: .touchUpInside)
        
        overlay.addSubview(startBtn)
        overlay.addSubview(stopBtn)
        overlay.addSubview(clearBtn)
        overlay.addSubview(exportBtn)
    }
    
    private func setupButton(_ btn: UIButton, title: String, color: UIColor, y: CGFloat, x: CGFloat = 20, width: CGFloat = 350) {
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 8
        btn.frame = CGRect(x: x, y: y, width: width, height: 44)
    }
    
    @objc private func intervalChanged() {
        let values = [1.0, 2.0, 5.0, 10.0]
        selectedInterval = values[intervalPicker.selectedSegmentIndex]
    }
    
    @objc private func startRecording() {
        isRecording = true
        statusLabel.text = "STATUS: RECORDING"
        statusLabel.textColor = .systemGreen
        detector.reset()
        
        samplingTimer = Timer.scheduledTimer(withTimeInterval: selectedInterval, repeats: true) { [weak self] _ in
            self?.processCurrentFrame()
        }
    }
    
    @objc private func stopRecording() {
        isRecording = false
        statusLabel.text = "STATUS: STOPPED"
        statusLabel.textColor = .white
        samplingTimer?.invalidate()
        samplingTimer = nil
    }
    
    @objc private func handleResetOrigin() {
        motionManager.resetOrigin()
        coordLabel.text = "COORD: X: 0.00, Y: 0.00"
    }
    
    private func processCurrentFrame() {
        guard let buffer = latestBuffer else { return }
        
        let cx = motionManager.currentX
        let cy = motionManager.currentY
        
        if let result = detector.detect(pixelBuffer: buffer) {
            DispatchQueue.main.async {
                self.resultLabel.text = String(format: "DETECTION: %@ (Conf: %.2f)", 
                                             result.isLoaded ? "LOAD" : "EMPTY",
                                             result.confidence)
                self.resultLabel.textColor = result.isLoaded ? .systemGreen : .yellow
                self.coordLabel.text = String(format: "COORD: X: %.2f, Y: %.2f", cx, cy)
            }
            
            logger.log(agvId: agvIdField.text ?? "UNK", 
                       isLoaded: result.isLoaded, 
                       confidence: result.confidence, 
                       ratio: result.changeRatio,
                       x: cx,
                       y: cy)
        }
    }
    
    @objc private func handleClear() {
        logger.clearData()
        let alert = UIAlertController(title: "Cleared", message: "CSV data has been deleted.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func handleExport() {
        guard let url = logger.getExportURL() else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(vc, animated: true)
    }
}
