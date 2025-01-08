//
//  CameraPreviewView.swift
//  Semantic Segmentation
//
//  Created by Kristian Emil on 23/12/2024.
//


//
//  CameraView.swift
//  Image Classifier
//
//  Created by Kristian Emil on 19/12/2024.
//

import SwiftUI
import AVFoundation
import Vision



// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.videoOrientation = .portrait
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds
    }
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var permissionGranted = false
    @Published var classificationResult: String = ""
    @Published var isLiveMode = false
    @Published var isTorchOn = false
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var lastAnalysis: Date = .distantPast
    private let minimumAnalysisInterval: TimeInterval = 0.5
    private var completion: ((UIImage) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
        setupVideoOutput()
    }
    
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            } else {
                device.torchMode = .off
                isTorchOn = false
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
            isTorchOn = false
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
        @unknown default:
            permissionGranted = false
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        // Add video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Add video output
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
    }
    
    private func setupVideoOutput() {
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        // Set flash mode based on torch state
        settings.flashMode = isTorchOn ? .on : .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func normalizePercentages(_ results: [VNClassificationObservation]) -> [(identifier: String, percentage: Int)] {
        var percentages = results.map { (identifier: $0.identifier, percentage: Int(round($0.confidence * 100))) }
        let totalPercentage = percentages.reduce(0) { $0 + $1.percentage }
        
        if totalPercentage != 100 {
            let diff = 100 - totalPercentage
            if let maxIndex = percentages.indices.max(by: { percentages[$0].percentage < percentages[$1].percentage }) {
                percentages[maxIndex].percentage += diff
            }
        }
        
        return percentages
    }
}

// MARK: - Photo Capture Delegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
        }
    }
}

// MARK: - Video Processing
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isLiveMode else { return }
        
        let currentDate = Date()
        guard currentDate.timeIntervalSince(lastAnalysis) > minimumAnalysisInterval else { return }
        lastAnalysis = currentDate
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        do {
            guard let model = try? DETRResnet50SemanticSegmentationF16(),
                  let vnModel = try? VNCoreMLModel(for: model.model) else { return }
            
            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                guard let results = request.results as? [VNClassificationObservation],
                      error == nil else { return }
                
                let normalizedResults = self?.normalizePercentages(results) ?? []
                let resultString = normalizedResults.map { result in
                    "\(result.identifier) (\(result.percentage)%)"
                }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    self?.classificationResult = resultString
                }
            }
            
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
        } catch {
            print("Classification error: \(error.localizedDescription)")
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraViewModel()
    var didCapturePhoto: (UIImage) -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
            
            // Camera UI
            VStack {
                // Top toolbar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Flashlight toggle
                    Button(action: { camera.toggleTorch() }) {
                        Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(camera.isTorchOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                    }
                    
                    // Mode toggle
                    Button(action: {
                        withAnimation {
                            camera.isLiveMode.toggle()
                        }
                    }) {
                        Image(systemName: camera.isLiveMode ? "camera.fill" : "video.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()
                
                Spacer()
                
                // Live classification results
                if camera.isLiveMode && !camera.classificationResult.isEmpty {
                    SegmentationResultsCard(results: camera.classificationResult)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom controls
                if !camera.isLiveMode {
                    HStack(spacing: 60) {
                        Spacer()
                        
                        // Shutter button
                        Button(action: {
                            camera.capturePhoto { image in
                                camera.stopSession()
                                didCapturePhoto(image)
                                dismiss()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 65, height: 65)
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            camera.startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
    }
}
