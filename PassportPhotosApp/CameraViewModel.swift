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

import Combine
import CoreGraphics
import Foundation
import Vision

enum CameraViewModelAction {
  // View setup and configuration actions
  case windowSizeDetected(CGRect)

  // Face detection actions
  case noFaceDetected
  case faceObservationDetected(FaceGeometryModel)
  case faceQualityObservationDetected(FaceQualityModel)

  // Other
  case toggleDebugMode
}

enum FaceDetectionState {
  case detectedFaceTooSmall
  case detectedFaceTooLarge
  case detectedFaceOffCentre
  case detectedFaceQualityTooLow
  case detectedFaceNotFacingForward
  case detectedFaceJustRight
}

struct FaceGeometryModel {
  let boundingBox: CGRect
  let roll: NSNumber
  let pitch: NSNumber
  let yaw: NSNumber
}

struct FaceQualityModel {
  let quality: Float
}

final class CameraViewModel: ObservableObject {
  // MARK: - Publishers
  @Published var debugModeEnabled: Bool
  @Published var hasDetectedValidFace: Bool
  @Published var faceGeometryState: FaceObservation<FaceGeometryModel> {
    didSet {
      faceDetectionState = calculateDetectedFaceValidity()
    }
  }

  @Published var faceQualityState: FaceObservation<FaceQualityModel> {
    didSet {
      faceDetectionState = calculateDetectedFaceValidity()
    }
  }
  @Published var faceDetectionState: FaceObservation<FaceDetectionState> {
    didSet {
      // Update `hasDetectedValidFace` shortcut value
      switch faceDetectionState {
      case .faceFound(let faceDetectionState):
        switch faceDetectionState {
        case .detectedFaceJustRight:
          hasDetectedValidFace = true
          return
        default:
          hasDetectedValidFace = false
          return
        }
      default:
        hasDetectedValidFace = false
      }
    }
  }

  // MARK: - Private variables
  var faceLayoutGuideFrame = CGRect(x: 0, y: 0, width: 200, height: 300)

  init() {
    hasDetectedValidFace = false
    faceGeometryState = .faceNotFound
    faceQualityState = .faceNotFound
    faceDetectionState = .faceNotFound

    #if DEBUG
      debugModeEnabled = true
    #else
      debugModeEnabled = false
    #endif
  }

  // MARK: Actions

  func perform(action: CameraViewModelAction) {
    switch action {
    case .windowSizeDetected(let windowRect):
      handleWindowSizeChanged(toRect: windowRect)
    case .noFaceDetected:
      publishNoFaceObserved()
    case .faceObservationDetected(let faceObservation):
      publishFaceObservation(faceObservation)
    case .faceQualityObservationDetected(let faceQualityObservation):
      publishFaceQualityObservation(faceQualityObservation)
    case .toggleDebugMode:
      toggleDebugMode()
    }
  }

  // MARK: Action handlers

  private func handleWindowSizeChanged(toRect: CGRect) {
    print(toRect)
    faceLayoutGuideFrame = CGRect(
      x: toRect.midX - faceLayoutGuideFrame.width / 2,
      y: toRect.midY - faceLayoutGuideFrame.height / 2,
      width: faceLayoutGuideFrame.width,
      height: faceLayoutGuideFrame.height
    )
  }

  private func publishNoFaceObserved() {
    DispatchQueue.main.async { [self] in
      faceGeometryState = .faceNotFound
      faceQualityState = .faceNotFound
      faceDetectionState = .faceNotFound
    }
  }

  private func publishFaceObservation(_ faceGeometryModel: FaceGeometryModel) {
    DispatchQueue.main.async { [self] in
      faceGeometryState = .faceFound(faceGeometryModel)
    }
  }

  private func publishFaceQualityObservation(_ faceQualityModel: FaceQualityModel) {
    DispatchQueue.main.async { [self] in
      faceQualityState = .faceFound(faceQualityModel)
    }
  }

  private func toggleDebugMode() {
    debugModeEnabled.toggle()
  }
}

// MARK: Private instance methods

extension CameraViewModel {
  func calculateDetectedFaceValidity() -> FaceObservation<FaceDetectionState> {
    // First, check if the geometry is correct
    switch faceGeometryState {
    case .faceNotFound:
      return .faceNotFound
    case .errored(let error):
      return .errored(error)
    case .faceFound(let faceGeometryModel):
      // First, check face is roughly the same size as the layout guide
      let boundingBox = faceGeometryModel.boundingBox
      if boundingBox.width > 1.2 * faceLayoutGuideFrame.width {
        return .faceFound(.detectedFaceTooLarge)
      } else if boundingBox.width * 1.2 < faceLayoutGuideFrame.width {
        return .faceFound(.detectedFaceTooSmall)
      }

      // Next, check face is roughly centered in the frame
      if abs(boundingBox.midX - faceLayoutGuideFrame.midX) > 50 {
        return .faceFound(.detectedFaceOffCentre)
      } else if abs(boundingBox.midY - faceLayoutGuideFrame.midY) > 50 {
        return .faceFound(.detectedFaceOffCentre)
      }

      if faceGeometryModel.roll.doubleValue < 1.2 || faceGeometryModel.roll.doubleValue > 1.6 {
        return .faceFound(.detectedFaceNotFacingForward)
      }

      if abs(CGFloat(faceGeometryModel.pitch.doubleValue)) > 0.1 {
        return .faceFound(.detectedFaceNotFacingForward)
      }

      if abs(CGFloat(faceGeometryModel.yaw.doubleValue)) > 0.1 {
        return .faceFound(.detectedFaceNotFacingForward)
      }
    }

    // Next, check quality
    switch faceQualityState {
    case .faceNotFound:
      return .faceNotFound
    case .errored(let error):
      return .errored(error)
    case .faceFound(let faceQualityModel):
      if faceQualityModel.quality < 0.2 {
        return .faceFound(.detectedFaceQualityTooLow)
      }

      return .faceFound(.detectedFaceJustRight)
    }
  }
}
