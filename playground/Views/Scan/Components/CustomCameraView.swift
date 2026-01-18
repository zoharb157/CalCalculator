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
            // Check camera permission before starting
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            print("📸 [CustomCameraView] onAppear - permission status: \(authStatus.rawValue)")
            
            if authStatus == .authorized {
                // Setup session first, wait for it to complete, then start
                camera.setupSession {
                    // Configuration complete, now start the session
                    // Preview will be set up in updateUIView when SwiftUI updates the view
                    camera.startSession()
                    updateCameraForMode()
                }
            } else {
                print("❌ Camera permission not authorized: \(authStatus.rawValue)")
            }
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
            // Document overlay - will show guide, detection happens on captured image
            DocumentOverlay(corners: [])
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
            Task { @MainActor in
                if let image = image {
                    self.capturedImage = image
                    self.showingHintInput = true
                }
            }
        }
    }
    
    private func handleBarcodeScanned(_ barcode: String) {
        HapticManager.shared.notification(.success)
        scannedBarcode = barcode
        
        // Capture a preview image along with the barcode
        camera.capturePhoto { image in
            Task { @MainActor in
                self.capturedImage = image
                self.showingHintInput = true
            }
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
        // Store view reference in coordinator for later preview setup
        context.coordinator.view = view
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update coordinator's view reference if needed
        context.coordinator.view = uiView
        // Setup preview if session is configured and preview doesn't exist
        if camera.isSessionConfigured && !camera.hasPreviewLayer {
            camera.setupPreview(in: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }
    
    class Coordinator {
        weak var view: UIView?
        let camera: CameraController
        private var cancellable: AnyCancellable?
        
        init(camera: CameraController) {
            self.camera = camera
            // Observe isSessionConfigured using Combine publisher (not KVO)
            cancellable = camera.$isSessionConfigured
                .sink { [weak self] isConfigured in
                    guard let self = self,
                          let view = self.view,
                          isConfigured,
                          !self.camera.hasPreviewLayer else { return }
                    self.camera.setupPreview(in: view)
                }
        }
    }
}

// MARK: - Camera Controller

class CameraController: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var scannedBarcode: String?
    // documentCorners removed - app only uses still images, not live video processing
    @Published var isSessionConfigured = false
    
    // AVCaptureSession is thread-safe and should be accessed from sessionQueue, not main actor
    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    // Video output removed - app only uses still images
    nonisolated(unsafe) private var photoOutput: AVCapturePhotoOutput?
    nonisolated(unsafe) private var metadataOutput: AVCaptureMetadataOutput?
    nonisolated(unsafe) private var previewLayer: AVCaptureVideoPreviewLayer?
    nonisolated(unsafe) private var currentMode: CaptureMode = .photo
    
    // Public property to check if preview layer exists
    var hasPreviewLayer: Bool {
        previewLayer != nil
    }
    
    // Simple completion handlers - accessed only on main actor
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    private var setupCompletion: (() -> Void)?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        // Don't setup session in init - wait for explicit start
        // Permission might not be requested yet
    }
    
    // MARK: - Setup
    
    func setupSession(completion: (() -> Void)? = nil) {
        // Check camera permission first
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard authStatus == .authorized else {
            print("❌ Camera permission not authorized: \(authStatus.rawValue)")
            completion?()
            return
        }
        setupCompletion = completion

        sessionQueue.async { [weak self] in
            self?.configureSession()
            DispatchQueue.main.async { [weak self] in
                self?.isSessionConfigured = true
                self?.setupCompletion?()
                self?.setupCompletion = nil
            }
        }
    }
    
    nonisolated private func configureSession() {
        print("📸 [CameraController] configureSession() called")
        guard !captureSession.isRunning else {
            print("📸 [CameraController] Session already running")
            return
        }
        
        // Verify permission on session queue
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📸 [CameraController] Permission check on session queue: \(authStatus.rawValue)")
        guard authStatus == .authorized else {
            print("❌ Permission check failed on session queue")
            return
        }
        
        print("📸 [CameraController] Beginning session configuration")
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // CRITICAL: Remove ALL existing outputs first to prevent stale delegates
        // This ensures no video output delegates are called (app only uses still images)
        let existingOutputs = captureSession.outputs
        for output in existingOutputs {
            // Remove any video data outputs (should not exist, but remove if present)
            if output is AVCaptureVideoDataOutput {
                print("⚠️ [CameraController] Removing existing video output (should not exist)")
                captureSession.removeOutput(output)
            }
        }
        
        // Also remove all existing inputs to ensure clean configuration
        let existingInputs = captureSession.inputs
        for input in existingInputs {
            captureSession.removeInput(input)
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ Failed to get video device")
            captureSession.commitConfiguration()
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("❌ Failed to create video input - may need permission")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("✅ [CameraController] Added video input")
        } else {
            print("⚠️ [CameraController] Cannot add video input")
        }
        
        // Add photo output - CRITICAL for photo capture
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
            print("✅ [CameraController] Added photo output")
        } else {
            print("❌ [CameraController] Cannot add photo output - this will cause crashes!")
            captureSession.commitConfiguration()
            return
        }
        
        // Add metadata output for barcodes
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .code93, .upce
            ]
            self.metadataOutput = metadataOutput
            // Set delegate on main actor
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            }
        }
        
        // Video output removed - app only uses still images for analysis
        // Document detection will be done on captured images, not live video frames
        
        captureSession.commitConfiguration()
        print("✅ [CameraController] Session configuration committed")
    }
    
    func setupPreview(in view: UIView) {
        print("📸 [CameraController] setupPreview() called")
        print("📸 [CameraController] View bounds: \(view.bounds)")
        print("📸 [CameraController] Session isRunning: \(captureSession.isRunning)")
        print("📸 [CameraController] Session inputs count: \(captureSession.inputs.count)")
        print("📸 [CameraController] Session outputs count: \(captureSession.outputs.count)")
        
        // Only create preview layer if it doesn't exist
        guard previewLayer == nil else {
            // Update frame if preview already exists
            previewLayer?.frame = view.bounds
            print("✅ [CameraController] Preview layer frame updated to: \(view.bounds)")
            return
        }
        
        // Create preview layer - session should already be configured at this point
        // AVCaptureVideoPreviewLayer can be created on main thread
        let newPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        newPreviewLayer.frame = view.bounds
        newPreviewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(newPreviewLayer)
        self.previewLayer = newPreviewLayer
        print("✅ [CameraController] Preview layer created and added to view")
        print("✅ [CameraController] Preview layer frame: \(newPreviewLayer.frame)")
        print("✅ [CameraController] Preview layer session: \(newPreviewLayer.session != nil ? "attached" : "nil")")
    }
    
    // MARK: - Session Control
    
    func startSession() {
        print("📸 [CameraController] startSession() called")
        // Check permission before starting
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("📸 [CameraController] Permission check in startSession: \(authStatus.rawValue)")
        guard authStatus == .authorized else {
            print("❌ Cannot start session - permission not authorized")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else {
                print("❌ [CameraController] self is nil in startSession")
                return
            }
            guard !self.captureSession.isRunning else {
                print("📸 [CameraController] Session already running")
                return
            }
            print("📸 [CameraController] Starting capture session")
            print("📸 [CameraController] Session inputs before start: \(self.captureSession.inputs.count)")
            print("📸 [CameraController] Session outputs before start: \(self.captureSession.outputs.count)")
            self.captureSession.startRunning()
            print("✅ [CameraController] Capture session started")
            print("✅ [CameraController] Session isRunning after start: \(self.captureSession.isRunning)")
            print("✅ [CameraController] Preview layer exists: \(self.previewLayer != nil)")
            if let preview = self.previewLayer {
                print("✅ [CameraController] Preview layer frame: \(preview.frame)")
                print("✅ [CameraController] Preview layer superlayer: \(preview.superlayer != nil ? "exists" : "nil")")
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
        }
    }
    
    // MARK: - Mode Control
    
    func updateMode(_ mode: CaptureMode) {
        print("📹 [CameraController] updateMode called: \(mode.rawValue) on queue: \(String(cString: __dispatch_queue_get_label(nil)))")
        currentMode = mode
        DispatchQueue.main.async {
            print("📹 [CameraController] Clearing scannedBarcode on main queue")
            self.scannedBarcode = nil
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
    
    func capturePhoto(completion: @escaping @Sendable (UIImage?) -> Void) {
        // Prevent multiple simultaneous captures
        guard !isCapturing else {
            completion(nil)
            return
        }
        
        // Set capturing state and store completion
        isCapturing = true
        photoCaptureCompletion = completion
        
        // Capture photo on session queue
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Check if photo output is still valid
            guard let photoOutput = self.photoOutput else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.photoCaptureCompletion = nil
                    completion(nil)
                }
                return
            }
            
            // Ensure session is running before capturing
            guard self.captureSession.isRunning else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.photoCaptureCompletion = nil
                    completion(nil)
                }
                return
            }
            
            // Create photo settings
            let settings = AVCapturePhotoSettings()
            if photoOutput.isFlashScene {
                settings.flashMode = .auto
            }
            
            // Capture photo
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 [PhotoOutput] didFinishProcessingPhoto called on queue: \(String(cString: __dispatch_queue_get_label(nil)))")
        
        // Handle error first
        if let error = error {
            print("❌ [PhotoOutput] Photo capture error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isCapturing = false
                let completion = self.photoCaptureCompletion
                self.photoCaptureCompletion = nil
                completion?(nil)
            }
            return
        }
        
        // Process photo data
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("❌ [PhotoOutput] Failed to create image from photo data")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isCapturing = false
                let completion = self.photoCaptureCompletion
                self.photoCaptureCompletion = nil
                completion?(nil)
            }
            return
        }
        
        // Call completion on main thread
        DispatchQueue.main.async { [weak self] in
            print("📸 [PhotoOutput] Calling completion on main queue")
            guard let self = self else { return }
            self.isCapturing = false
            let completion = self.photoCaptureCompletion
            self.photoCaptureCompletion = nil
            completion?(image)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }
        
        // Delegate is already called on main queue (set in configureSession)
        // currentMode is nonisolated(unsafe) so can be accessed directly
        // scannedBarcode is @Published, so update on main queue
        if self.currentMode == .barcode {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.scannedBarcode == nil else { return }
                self.scannedBarcode = stringValue
            }
        }
    }
}

// Video output delegate removed - app only uses still images for analysis
// Document detection will be performed on captured images when needed

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

