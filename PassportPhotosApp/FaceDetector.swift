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
  weak var model: CameraViewModel?

  var sequenceHandler = VNSequenceRequestHandler()
  var currentFrameBuffer: CVImageBuffer?

  var subscriptions = Set<AnyCancellable>()

  let imageProcessingQueue = DispatchQueue(
    label: "Image Processing Queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem
  )
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    let detectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFaceRectangles)
    detectFaceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision2

    currentFrameBuffer = imageBuffer
    do {
      try sequenceHandler.perform(
        [detectFaceRectanglesRequest],
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
      boundingBox: convertedBoundingBox
    )

    model.perform(action: .faceObservationDetected(faceObservationModel))
  }

  func detectedFaceQualityRequest(request: VNRequest, error: Error?) { }

  func detectedSegmentationRequest(request: VNRequest, error: Error?) { }

  func savePassportPhoto(from pixelBuffer: CVPixelBuffer) { }

  func removeBackgroundFrom(image: CIImage, using maskPixelBuffer: CVPixelBuffer) -> CIImage {
    return image
  }
}
