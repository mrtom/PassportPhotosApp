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
import Combine
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

protocol FaceDetectorDelegate: NSObjectProtocol {
  func convertFromMetadataToPreviewRect(rect: CGRect) -> CGRect
  func draw(image: CIImage)
}

class FaceDetector: NSObject {
  weak var viewDelegate: FaceDetectorDelegate?
  weak var model: CameraViewModel? {
    didSet {
      model?.$hideBackgroundModeEnabled
        .dropFirst()
        .sink { hideBackgroundMode in
          self.isReplacingBackground = hideBackgroundMode
        }
        .store(in: &subscriptions)

      model?.shutterReleased.sink { completion in
        switch completion {
        case .finished:
          return
        case .failure(let error):
          print("Received error: \(error)")
        }
      } receiveValue: { _ in
        self.isCapturingPhoto = true
      }
      .store(in: &subscriptions)
    }
  }

  var sequenceHandler = VNSequenceRequestHandler()
  var isCapturingPhoto = false
  var isReplacingBackground = false
  var currentFrameBuffer: CVImageBuffer?

  var subscriptions = Set<AnyCancellable>()

  let imageProcessingQueue = DispatchQueue(
    label: "Image Processing Queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem
  )

  func capturePhoto() {
    isCapturingPhoto = true
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
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

    let detectSegmentationRequest = VNGeneratePersonSegmentationRequest(completionHandler: detectedSegmentationRequest)
    detectSegmentationRequest.qualityLevel = .balanced
    detectSegmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

    currentFrameBuffer = imageBuffer
    do {
      try sequenceHandler.perform(
        [detectFaceRectanglesRequest, detectCaptureQualityRequest, detectSegmentationRequest],
        on: imageBuffer,
        orientation: .leftMirrored)
    } catch {
      print(error.localizedDescription)
    }
  }
}

// MARK: - Private methods

extension FaceDetector {
  func detectedFaceRectangles(request: VNRequest, error: Error?) {
    guard let model = model, let viewDelegate = viewDelegate else {
      return
    }

    guard
      let results = request.results as? [VNFaceObservation],
      let result = results.first
    else {
      model.perform(action: .noFaceDetected)
      return
    }

    let convertedBoundingBox =
      viewDelegate.convertFromMetadataToPreviewRect(rect: result.boundingBox)

    let faceObservationModel = FaceGeometryModel(
      boundingBox: convertedBoundingBox,
      roll: result.roll ?? 0,
      pitch: result.pitch ?? 0,
      yaw: result.yaw ?? 0
    )

    model.perform(action: .faceObservationDetected(faceObservationModel))
  }

  func detectedFaceQualityRequest(request: VNRequest, error: Error?) {
    guard let model = model else {
      return
    }

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

  func detectedSegmentationRequest(request: VNRequest, error: Error?) {
    guard
      let results = request.results as? [VNPixelBufferObservation],
      let result = results.first,
      let currentFrameBuffer = currentFrameBuffer
    else {
      return
    }

    if isReplacingBackground {
      let originalImage = CIImage(cvImageBuffer: currentFrameBuffer)
      let maskPixelBuffer = result.pixelBuffer
      let outputImage = removeBackgroundFrom(image: originalImage, using: maskPixelBuffer)
      viewDelegate?.draw(image: outputImage.oriented(.upMirrored))
    } else {
      let originalImage = CIImage(cvImageBuffer: currentFrameBuffer).oriented(.upMirrored)
      viewDelegate?.draw(image: originalImage)
    }
  }

  func savePassportPhoto(from pixelBuffer: CVPixelBuffer) {
    guard let model = model else {
      return
    }

    imageProcessingQueue.async { [self] in
      let originalImage = CIImage(cvPixelBuffer: pixelBuffer)
      var outputImage = originalImage

      if isReplacingBackground {
        let detectSegmentationRequest = VNGeneratePersonSegmentationRequest()
        detectSegmentationRequest.qualityLevel = .accurate
        detectSegmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

        try? sequenceHandler.perform(
          [detectSegmentationRequest],
          on: pixelBuffer,
          orientation: .leftMirrored
        )

        if let maskPixelBuffer = detectSegmentationRequest.results?.first?.pixelBuffer {
          outputImage = removeBackgroundFrom(image: originalImage, using: maskPixelBuffer)
        }
      }


      let coreImageWidth = outputImage.extent.width
      let coreImageHeight = outputImage.extent.height

      let desiredImageHeight = coreImageWidth * 4 / 3

      // Calculate frame of photo
      let yOrigin = (coreImageHeight - desiredImageHeight) / 2
      let photoRect = CGRect(x: 0, y: yOrigin, width: coreImageWidth, height: desiredImageHeight)

      let context = CIContext()
      if let cgImage = context.createCGImage(outputImage, from: photoRect) {
        let passportPhoto = UIImage(cgImage: cgImage, scale: 1, orientation: .upMirrored)

        DispatchQueue.main.async {
          model.perform(action: .savePhoto(passportPhoto))
        }
      }
    }
  }

  func removeBackgroundFrom(image: CIImage, using maskPixelBuffer: CVPixelBuffer) -> CIImage {
    var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

    let originalImage = image.oriented(.right)

    // Scale the mask image to fit the bounds of the video frame.
    let scaleX = originalImage.extent.width / maskImage.extent.width
    let scaleY = originalImage.extent.height / maskImage.extent.height
    maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY)).oriented(.upMirrored)

    let backgroundImage = CIImage(color: .white).clampedToExtent().cropped(to: originalImage.extent)

    let blendFilter = CIFilter.blendWithRedMask()
    blendFilter.inputImage = originalImage
    blendFilter.backgroundImage = backgroundImage
    blendFilter.maskImage = maskImage

    if let outputImage = blendFilter.outputImage?.oriented(.left) {
      return outputImage
    }

    return originalImage
  }
}
