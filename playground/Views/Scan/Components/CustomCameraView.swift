//
//  CustomCameraView.swift
//  playground
//
//  Custom camera view with three capture modes:
//  - Barcode Scanner
//  - Image Capture
//  - Document Capture
//

import SwiftUI
import UIKit
import AVFoundation
import Vision
import Combine

// MARK: - Capture Mode

enum CaptureMode: String, CaseIterable {
    case barcode = "Barcode"
    case photo = "Photo"
    case document = "Document"
    
    var icon: String {
        switch self {
        case .barcode: return "barcode.viewfinder"
        case .photo: return "camera"
        case .document: return "doc.text.viewfinder"
        }
    }
    
    var description: String {
        switch self {
        case .barcode: return "Scan product barcode"
        case .photo: return "Take a photo of your meal"
        case .document: return "Capture menu or receipt"
        }
    }
    
    /// Convert to API ScanMode
    func toScanMode() -> ScanMode {
        switch self {
        case .barcode: return .barcode
        case .photo: return .food
        case .document: return .label
        }
    }
}

// MARK: - Capture Result

enum CaptureResult {
    case image(UIImage)
    case barcode(String, UIImage?) // barcode value and optional preview image
    case document(UIImage)
    case cancelled
}

// MARK: - Custom Camera View

struct CustomCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedMode: CaptureMode = .photo
    @State private var flashEnabled = false
    @State private var showingHintInput = false
    @State private var foodHint = ""
    @State private var capturedImage: UIImage?
    @State private var scannedBarcode: String?
    
    let onCapture: (CaptureResult, String?) -> Void
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return ZStack {
            // Camera preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
            
            // Mode-specific overlay
            overlayForCurrentMode
                .ignoresSafeArea()
            
            // Controls
            VStack {
                topControls
                
                Spacer()
                
                bottomControls
            }
        }
        .onAppear {
            camera.startSession()
            updateCameraForMode()
        }
        .onDisappear {
            camera.stopSession()
        }
        .onChange(of: selectedMode) { _, newMode in
            updateCameraForMode()
        }
        .onChange(of: camera.scannedBarcode) { _, barcode in
            if let barcode = barcode, selectedMode == .barcode {
                handleBarcodeScanned(barcode)
            }
        }
        .sheet(isPresented: $showingHintInput) {
            hintInputSheet
        }
    }
    
    // MARK: - Overlays
    
    @ViewBuilder
    private var overlayForCurrentMode: some View {
        switch selectedMode {
        case .barcode:
            BarcodeOverlay()
        case .photo:
            PhotoOverlay()
        case .document:
            DocumentOverlay(corners: camera.documentCorners)
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        HStack {
            // Close button
            Button {
                onCapture(.cancelled, nil)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            
            Spacer()
            
            // Flash toggle
            Button {
                flashEnabled.toggle()
                camera.toggleFlash(flashEnabled)
            } label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundStyle(flashEnabled ? .yellow : .white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Mode description
            Text(selectedMode.description)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.6)))
            
            // Capture button (hidden for barcode mode - auto-captures)
            if selectedMode != .barcode {
                captureButton
            } else {
                // Barcode scanning indicator
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text(localizationManager.localizedString(for: AppStrings.Scanning.scanning))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 20)
            }
            
            // Mode selector
            modeSelector
                .padding(.bottom, 30)
        }
    }
    
    private var captureButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .disabled(camera.isCapturing)
    }
    
    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                        Text(mode.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(selectedMode == mode ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedMode == mode ?
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.2)) :
                        nil
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.6))
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Hint Input Sheet
    
    private var hintInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview image
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.Scanning.addNoteOptional))
                        .font(.headline)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Scanning.describeFoodForAccuracy))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                TextField("e.g., Homemade chicken salad, about 400g", text: $foodHint, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(localizationManager.localizedString(for: AppStrings.Scanning.skip)) {
                        submitCapture(withHint: nil)
                    }
                    .foregroundStyle(.secondary)
                    
                    Button {
                        submitCapture(withHint: foodHint.isEmpty ? nil : foodHint)
                    } label: {
                        Text(localizationManager.localizedString(for: AppStrings.Scanning.analyze))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.blue)
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Scanning.confirm))
                .id("confirm-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Scanning.retake)) {
                        showingHintInput = false
                        capturedImage = nil
                        scannedBarcode = nil
                        foodHint = ""
                    }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
    
    // MARK: - Actions
    
    private func updateCameraForMode() {
        camera.updateMode(selectedMode)
    }
    
    private func capturePhoto() {
        camera.capturePhoto { image in
            if let image = image {
                self.capturedImage = image
                self.showingHintInput = true
            }
        }
    }
    
    private func handleBarcodeScanned(_ barcode: String) {
        HapticManager.shared.notification(.success)
        scannedBarcode = barcode
        
        // Capture a preview image along with the barcode
        camera.capturePhoto { image in
            self.capturedImage = image
            self.showingHintInput = true
        }
    }
    
    private func submitCapture(withHint hint: String?) {
        showingHintInput = false
        
        let result: CaptureResult
        
        if let barcode = scannedBarcode {
            result = .barcode(barcode, capturedImage)
        } else if let image = capturedImage {
            switch selectedMode {
            case .document:
                result = .document(image)
            default:
                result = .image(image)
            }
        } else {
            result = .cancelled
        }
        
        onCapture(result, hint)
        dismiss()
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.setupPreview(in: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Camera Controller

class CameraController: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var scannedBarcode: String?
    @Published var documentCorners: [CGPoint] = []
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentMode: CaptureMode = .photo
    
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Setup
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        // Add metadata output for barcodes
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93, .upce
            ]
            self.metadataOutput = metadataOutput
        }
        
        // Add video output for document detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        captureSession.commitConfiguration()
    }
    
    func setupPreview(in view: UIView) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // MARK: - Mode Control
    
    func updateMode(_ mode: CaptureMode) {
        currentMode = mode
        DispatchQueue.main.async {
            self.scannedBarcode = nil
            self.documentCorners = []
        }
    }
    
    // MARK: - Flash Control
    
    func toggleFlash(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle failed: \(error)")
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isCapturing = true
        }
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
            
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                self.photoCaptureCompletion?(nil)
                return
            }
            
            self.photoCaptureCompletion?(image)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }
        
        DispatchQueue.main.async {
            if self.currentMode == .barcode && self.scannedBarcode == nil {
                self.scannedBarcode = stringValue
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Check mode on background thread first
        guard currentMode == .document else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let rect = results.first else {
                DispatchQueue.main.async {
                    self?.documentCorners = []
                }
                return
            }
            
            let corners = [
                rect.topLeft,
                rect.topRight,
                rect.bottomRight,
                rect.bottomLeft
            ].map { CGPoint(x: $0.x, y: 1 - $0.y) }
            
            DispatchQueue.main.async {
                self?.documentCorners = corners
            }
        }
        
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Overlay Views

struct BarcodeOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let scanAreaWidth = geometry.size.width * 0.8
            let scanAreaHeight: CGFloat = 200
            
            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: scanAreaWidth, height: scanAreaHeight)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // Scan area border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: scanAreaWidth, height: scanAreaHeight)
                
                // Corner accents
                BarcodeCorners(width: scanAreaWidth, height: scanAreaHeight)
                
                // Scanning line animation
                ScanningLine(width: scanAreaWidth - 40, height: scanAreaHeight - 40)
            }
        }
    }
}

struct BarcodeCorners: View {
    let width: CGFloat
    let height: CGFloat
    let cornerLength: CGFloat = 30
    let lineWidth: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Top-left
            CornerShape(corner: .topLeft, length: cornerLength)
                .stroke(Color.green, lineWidth: lineWidth)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: (UIScreen.main.bounds.width - width) / 2 + cornerLength / 2,
                         y: (UIScreen.main.bounds.height - height) / 2 + cornerLength / 2)
            
            // Top-right
            CornerShape(corner: .topRight, length: cornerLength)
                .stroke(Color.green, lineWidth: lineWidth)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: (UIScreen.main.bounds.width + width) / 2 - cornerLength / 2,
                         y: (UIScreen.main.bounds.height - height) / 2 + cornerLength / 2)
            
            // Bottom-left
            CornerShape(corner: .bottomLeft, length: cornerLength)
                .stroke(Color.green, lineWidth: lineWidth)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: (UIScreen.main.bounds.width - width) / 2 + cornerLength / 2,
                         y: (UIScreen.main.bounds.height + height) / 2 - cornerLength / 2)
            
            // Bottom-right
            CornerShape(corner: .bottomRight, length: cornerLength)
                .stroke(Color.green, lineWidth: lineWidth)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: (UIScreen.main.bounds.width + width) / 2 - cornerLength / 2,
                         y: (UIScreen.main.bounds.height + height) / 2 - cornerLength / 2)
        }
    }
}

enum Corner {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct CornerShape: Shape {
    let corner: Corner
    let length: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: rect.width - length, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: length))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: rect.height - length))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: length, y: rect.height))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.width - length, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - length))
        }
        
        return path
    }
}

struct ScanningLine: View {
    let width: CGFloat
    let height: CGFloat
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .green.opacity(0.8), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = height / 2 - 20
                }
            }
            .onDisappear {
                offset = -height / 2 + 20
            }
    }
}

struct PhotoOverlay: View {
    var body: some View {
        // Simple photo mode - grid lines for composition
        GeometryReader { geometry in
            let thirdWidth = geometry.size.width / 3
            let thirdHeight = geometry.size.height / 3
            
            ZStack {
                // Vertical lines
                ForEach(1..<3) { i in
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1)
                        .position(x: thirdWidth * CGFloat(i), y: geometry.size.height / 2)
                }
                
                // Horizontal lines
                ForEach(1..<3) { i in
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: thirdHeight * CGFloat(i))
                }
            }
        }
    }
}

struct DocumentOverlay: View {
    let corners: [CGPoint]
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                
                // Document detection outline
                if corners.count == 4 {
                    DocumentShape(corners: corners, size: geometry.size)
                        .stroke(Color.green, lineWidth: 3)
                    
                    // Corner dots
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .position(
                                x: corners[index].x * geometry.size.width,
                                y: corners[index].y * geometry.size.height
                            )
                    }
                } else {
                    // No document detected - show guide
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(localizationManager.localizedString(for: AppStrings.Scanning.alignDocument))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}

struct DocumentShape: Shape {
    let corners: [CGPoint]
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard corners.count == 4 else { return path }
        
        let scaledCorners = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        
        path.move(to: scaledCorners[0])
        for i in 1..<4 {
            path.addLine(to: scaledCorners[i])
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview {
    CustomCameraView { result, hint in
        print("Captured: \(result), hint: \(hint ?? "none")")
    }
}
