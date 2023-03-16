//
//  ViewController.swift
//  JustSample
//
//  Created by UMCios on 2023/02/03.
//
import UIKit
import AVFoundation
import MLKit
import MLKitTextRecognitionKorean

enum CameraSetupError: Error {
    case sessionAlreadyRunning
}

extension CameraSetupError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyRunning:
            return NSLocalizedString("Capture session is already running.", comment: "")
        }
    }
}

class CameraViewController: UIViewController {
    
    private var textRecognizer: TextRecognizer!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureSession: AVCaptureSession!
    
    var capturedFileURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            let authorized = await checkCameraAuthorizationStatus()
            if authorized {
                setTextRecognizer()
                setPreview()
                setPanel()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }
    
    func checkCameraAuthorizationStatus() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            // The user has previously granted permission to access the camera.
            do {
                try setupCamera()
                return true
            } catch {
                print("setup camera error")
                return false
            }
        case .notDetermined:
            // The user has not yet been asked for camera access.
            do {
                await AVCaptureDevice.requestAccess(for: .video)
                // The user granted permission.
                try setupCamera()
                return true
            } catch {
                let alertController = UIAlertController(title: "Camera Access Denied", message: "This app requires access to your device's camera to function properly. To grant access, go to Settings > Privacy > Camera and enable camera access for this app.", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                return false
            }
        case .denied, .restricted:
            // The user has previously denied or restricted camera access.
            let alertController = UIAlertController(title: "Camera Access Denied", message: "This app requires access to your device's camera to function properly. To grant access, go to Settings > Privacy > Camera and enable camera access for this app.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            return false
        @unknown default:
            return false
        }
    }
    
    func setTextRecognizer() {
        let options = KoreanTextRecognizerOptions()
        textRecognizer = TextRecognizer.textRecognizer(options: options)
    }
    
    func setupCamera() throws {
        captureSession = AVCaptureSession()
        guard !captureSession.isRunning else {
            throw CameraSetupError.sessionAlreadyRunning
        }
        setCaptureSessionOutput()
        setCaptureSessionInput()
    }
    
    func setPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    func setPanel() {
        let remotePanel = UIView()
        remotePanel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        remotePanel.frame = CGRect(x: 0, y: view.bounds.height - 100, width: view.bounds.width, height: 100)
        view.addSubview(remotePanel)
        
        let recordButton = UIButton(type: .system)
        recordButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        recordButton.tintColor = .white // set initial color to white
        recordButton.isSelected = false // set initial state to unselected
        recordButton.frame = CGRect(x: 25, y: 25, width: 50, height: 50)
        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchUpInside)
        remotePanel.addSubview(recordButton)
        
        let playButton = UIButton(type: .system)
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = .white
        playButton.frame = CGRect(x: 100, y: 25, width: 50, height: 50)
        playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)
        remotePanel.addSubview(playButton)
        
        let captureButton = UIButton(type: .system)
        captureButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.frame = CGRect(x: 175, y: 25, width: 50, height: 50)
        captureButton.addTarget(self, action: #selector(captureButtonPressed), for: .touchUpInside)
        remotePanel.addSubview(captureButton)
    }
    
    @objc func recordButtonPressed(_ sender: UIButton) {
        sender.isSelected.toggle()
        sender.tintColor = sender.isSelected ? .red : .white
        
        // Add your recording logic here
        if sender.isSelected {
            do {
                try startRecording()
                setMovieFileOutput()
            } catch {
                print("Error starting the recording: \(error)")
            }
        } else {
            stopRecording()
        }
    }
    
    private func setCaptureSessionOutput() {
        captureSession.beginConfiguration()
        // When performing latency tests to determine ideal capture settings,
        // run the app in 'release' mode to get accurate performance metrics
        captureSession.sessionPreset = AVCaptureSession.Preset.medium
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        let outputQueue = DispatchQueue(label: "streamingQueue")
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard captureSession.canAddOutput(output) else {
            print("Failed to add capture session output.")
            return
        }
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
    }
    
    private func setCaptureSessionInput() {
        guard let device = captureDevice(forPosition: .back) else { return }
        do {
            captureSession.beginConfiguration()
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            captureSession.commitConfiguration()
        } catch {
            print("Failed to create capture device input: \(error.localizedDescription)")
        }
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    @objc func captureButtonPressed(_ sender: UIButton) {
        let photoOutput = captureSession.outputs.first { $0 is AVCapturePhotoOutput } as? AVCapturePhotoOutput
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        
        // Set highResolutionCaptureEnabled to true
        photoOutput?.isHighResolutionCaptureEnabled = true
        
        photoOutput?.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @objc func playButtonPressed() {
        stopRecording()
        guard let fileURL = capturedFileURL else {
            print("Recorded file URL is nil")
            return
        }
        
        // Handle the play button pressed event as desired
        print("Playing recorded video: \(fileURL)")
        let playVC = PlayVideoViewController(videoURL: fileURL)
        present(playVC, animated: true, completion: nil)
    }
    
    func startRecording() throws {
        // Set up the device input
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            fatalError("No video device found")
        }
        let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
        if captureSession.canAddInput(captureDeviceInput) {
            captureSession.addInput(captureDeviceInput)
        }
        
        // Set up the video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        startSession()
    }
    
    func stopRecording() {
        let movieFileOutput = captureSession.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput
        guard let output = movieFileOutput, output.isRecording else { return }
        
        output.stopRecording()
    }
    
    func setMovieFileOutput() {
        let movieFileOutput = captureSession.outputs.first(where: { $0 is AVCaptureMovieFileOutput }) as? AVCaptureMovieFileOutput
        guard let output = movieFileOutput else { return }
        
        // If recording is already in progress, stop it
        if output.isRecording {
            output.stopRecording()
            return
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputFileURL = documentsDirectory.appendingPathComponent("video.mov")
        output.startRecording(to: outputFileURL, recordingDelegate: self)
    }

    func imageOrientation(
        deviceOrientation: UIDeviceOrientation,
        cameraPosition: AVCaptureDevice.Position
    ) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return cameraPosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return cameraPosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return cameraPosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return cameraPosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            return .up
        }
    }
    
    private func startSession() {
        captureSession.startRunning()
    }
    
    private func stopSession() {
        captureSession.stopRunning()
    }
    
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording to \(fileURL)")
        capturedFileURL = nil
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
        } else {
            print("Finished recording to \(outputFileURL)")
            capturedFileURL = outputFileURL
        }
    }
    
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error creating UIImage from photo data")
            return
        }
        let visionImage = VisionImage(image: image)
        visionImage.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation, cameraPosition: .back)
        // Set the captured image to the UIImageView
    }
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        let visionImage = VisionImage(image: uiImage)
        
        // Set the orientation of the VisionImage based on the device orientation
        let deviceOrientation = UIDevice.current.orientation
        visionImage.orientation = imageOrientation(deviceOrientation: deviceOrientation, cameraPosition: .back)
        // Get the size of the image buffer
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        textRecognizer.process(visionImage) { result, error in
            guard error == nil, let result = result else {
                print("Error recognizing text: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            var allLines: [TextLine] = []
            // Iterate over each block in the result
            for block in result.blocks {
                // Get the bounding box of the block and convert it to the coordinate space of the preview layer
                //print(block.text)
                allLines.append(contentsOf: block.lines)
            }
            
            DispatchQueue.main.async { [weak self] in
                // Update the UI with the recognized text blocks
            }
        }
    }
}
