/// Copyright (c) 2021 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import AVFoundation
import SwiftUI
import UIKit
import Vision

struct CameraView: UIViewControllerRepresentable {
  typealias UIViewControllerType = CameraViewController

  private(set) var model: CameraViewModel

  func makeUIViewController(context: Context) -> CameraViewController {
    let viewController = CameraViewController(model: model)
    return viewController
  }

  func updateUIViewController(_ uiViewController: CameraViewController, context: Context) { }

  func makeCoordinator() -> CameraViewCoordinator {
    CameraViewCoordinator()
  }

  class CameraViewCoordinator { }
}

final class CameraViewController: UIViewController {
  var model: CameraViewModel

  var sequenceHandler = VNSequenceRequestHandler()
  var previewLayer: AVCaptureVideoPreviewLayer?
  var isCapturingPhoto = false

  let session = AVCaptureSession()

  init(model: CameraViewModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  let dataOutputQueue = DispatchQueue(
    label: "video data queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem
  )

  override func viewDidLoad() {
    super.viewDidLoad()
    configureCaptureSession()

    model.onShutterClick = { [weak self] in
      self?.isCapturingPhoto = true
    }

    session.startRunning()
  }
}

// MARK: - Video Processing methods

extension CameraViewController {
  func configureCaptureSession() {
    // Define the capture device we want to use
    guard let camera = AVCaptureDevice.default(
      .builtInWideAngleCamera,
      for: .video,
      position: .front
    ) else {
      fatalError("No front video camera available")
    }

    // Connect the camera to the capture session input
    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      session.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }

    // Create the video data output
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    // Add the video output to the capture session
    session.addOutput(videoOutput)

    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait

    // Configure the preview layer
    previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer?.videoGravity = .resizeAspect
    previewLayer?.frame = view.bounds
    if let previewLayer = previewLayer {
      view.layer.insertSublayer(previewLayer, at: 0)
    }
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    if isCapturingPhoto {
      isCapturingPhoto = false

      savePassportPhoto(from: imageBuffer)
    }

    let detectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFaceRectangles)
    detectFaceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3

    let detectCaptureQualityRequest = VNDetectFaceCaptureQualityRequest(completionHandler: detectedFaceQualityRequest)
    detectCaptureQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision2

    do {
      try sequenceHandler.perform(
        [detectFaceRectanglesRequest, detectCaptureQualityRequest],
        on: imageBuffer,
        orientation: .leftMirrored)
    } catch {
      print(error.localizedDescription)
    }
  }
}

// MARK: - Private methods

extension CameraViewController {
  func detectedFaceRectangles(request: VNRequest, error: Error?) {
    guard
      let results = request.results as? [VNFaceObservation],
      let result = results.first
    else {
      model.perform(action: .noFaceDetected)
      return
    }

    let faceObservationModel = FaceGeometryModel(
      boundingBox: convert(rect: result.boundingBox),
      roll: result.roll ?? 0,
      pitch: result.pitch ?? 0,
      yaw: result.yaw ?? 0
    )

    model.perform(action: .faceObservationDetected(faceObservationModel))
  }

  func detectedFaceQualityRequest(request: VNRequest, error: Error?) {
    guard
      let results = request.results as? [VNFaceObservation],
      let result = results.first
    else {
      model.perform(action: .noFaceDetected)
      return
    }

    let faceQualityModel = FaceQualityModel(
      quality: result.faceCaptureQuality ?? 0
    )

    model.perform(action: .faceQualityObservationDetected(faceQualityModel))
  }

  func convert(rect: CGRect) -> CGRect {
    guard let previewLayer = previewLayer else {
      return CGRect.zero
    }

    return previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
  }

  func savePassportPhoto(from pixelBuffer: CVPixelBuffer) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let coreImageWidth = ciImage.extent.width
    let coreImageHeight = ciImage.extent.height

    let desiredImageHeight = coreImageWidth * 4 / 3

    // Calculate frame of photo
    let yOrigin = (coreImageHeight - desiredImageHeight) / 2
    let photoRect = CGRect(x: 0, y: yOrigin, width: coreImageWidth, height: desiredImageHeight)

    let context = CIContext()
    if let cgImage = context.createCGImage(ciImage, from: photoRect) {
      let passportPhoto = UIImage(cgImage: cgImage, scale: 1, orientation: .upMirrored)
      model.perform(action: .savePhoto(passportPhoto))
    }
  }
}
