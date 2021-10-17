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

enum FaceDetectedState {
  case faceDetected
  case noFaceDetected
  case faceDetectionErrored
}

enum FaceBoundsState {
  case unknown
  case detectedFaceTooSmall
  case detectedFaceTooLarge
  case detectedFaceOffCentre
  case detectedFaceAppropriateSizeAndPosition
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

  // MARK: - Publishers of derived state
  @Published private(set) var hasDetectedValidFace: Bool
  @Published private(set) var isAcceptableRoll: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptablePitch: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableYaw: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableBounds: FaceBoundsState {
    didSet {
      calculateDetectedFaceValidity()
    }
  }
  @Published private(set) var isAcceptableQuality: Bool {
    didSet {
      calculateDetectedFaceValidity()
    }
  }

  // MARK: - Publishers of Vision data directly
  @Published private(set) var faceDetectedState: FaceDetectedState
  @Published private(set) var faceGeometryState: FaceObservation<FaceGeometryModel> {
    didSet {
      processUpdatedFaceGeometry()
    }
  }

  @Published private(set) var faceQualityState: FaceObservation<FaceQualityModel> {
    didSet {
      processUpdatedFaceQuality()
    }
  }

  // MARK: - Private variables
  var faceLayoutGuideFrame = CGRect(x: 0, y: 0, width: 200, height: 300)

  // MARK: - Vision framework state


  init() {
    faceDetectedState = .noFaceDetected
    isAcceptableRoll = false
    isAcceptablePitch = false
    isAcceptableYaw = false
    isAcceptableBounds = .unknown
    isAcceptableQuality = false

    hasDetectedValidFace = false
    faceGeometryState = .faceNotFound
    faceQualityState = .faceNotFound
    // faceDetectionState = .faceNotFound

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
      faceDetectedState = .noFaceDetected
      faceGeometryState = .faceNotFound
      faceQualityState = .faceNotFound
    }
  }

  private func publishFaceObservation(_ faceGeometryModel: FaceGeometryModel) {
    DispatchQueue.main.async { [self] in
      faceDetectedState = .faceDetected
      faceGeometryState = .faceFound(faceGeometryModel)
    }
  }

  private func publishFaceQualityObservation(_ faceQualityModel: FaceQualityModel) {
    DispatchQueue.main.async { [self] in
      faceDetectedState = .faceDetected
      faceQualityState = .faceFound(faceQualityModel)
    }
  }

  private func toggleDebugMode() {
    debugModeEnabled.toggle()
  }
}

// MARK: Private instance methods

extension CameraViewModel {
  func invalidateFaceGeometryState() {
    isAcceptableRoll = false
    isAcceptablePitch = false
    isAcceptableYaw = false
    isAcceptableBounds = .unknown
  }

  func processUpdatedFaceGeometry() {
    switch faceGeometryState {
    case .faceNotFound:
      invalidateFaceGeometryState()
    case .errored(let error):
      print(error.localizedDescription)
      invalidateFaceGeometryState()
    case .faceFound(let faceGeometryModel):
      let boundingBox = faceGeometryModel.boundingBox
      let roll = faceGeometryModel.roll.doubleValue
      let pitch = faceGeometryModel.pitch.doubleValue
      let yaw = faceGeometryModel.yaw.doubleValue

      updateAcceptableBounds(using: boundingBox)
      updateAcceptableRollPitchYaw(using: roll, pitch: pitch, yaw: yaw)
    }
  }

  func updateAcceptableBounds(using boundingBox: CGRect) {
    // First, check face is roughly the same size as the layout guide
    if boundingBox.width > 1.2 * faceLayoutGuideFrame.width {
      isAcceptableBounds = .detectedFaceTooLarge
    } else if boundingBox.width * 1.2 < faceLayoutGuideFrame.width {
      isAcceptableBounds = .detectedFaceTooSmall
    } else {
      // Next, check face is roughly centered in the frame
      if abs(boundingBox.midX - faceLayoutGuideFrame.midX) > 50 {
        isAcceptableBounds = .detectedFaceOffCentre
      } else if abs(boundingBox.midY - faceLayoutGuideFrame.midY) > 50 {
        isAcceptableBounds = .detectedFaceOffCentre
      } else {
        isAcceptableBounds = .detectedFaceAppropriateSizeAndPosition
      }
    }
  }

  func updateAcceptableRollPitchYaw(using roll: Double, pitch: Double, yaw: Double) {
    if roll > 1.2 || roll < 1.6 {
      isAcceptableRoll = true
    } else {
      isAcceptableRoll = false
    }

    if abs(CGFloat(pitch)) < 0.2 {
      isAcceptablePitch = true
    } else {
      isAcceptablePitch = false
    }

    if abs(CGFloat(yaw)) < 0.15 {
      isAcceptableYaw = true
    } else {
      isAcceptableYaw = false
    }
  }

  func processUpdatedFaceQuality() {
    switch faceQualityState {
    case .faceNotFound:
      isAcceptableQuality = false
    case .errored(let error):
      print(error.localizedDescription)
      isAcceptableQuality = false
    case .faceFound(let faceQualityModel):
      if faceQualityModel.quality < 0.2 {
        isAcceptableQuality = false
      }

      isAcceptableQuality = true
    }
  }

  func calculateDetectedFaceValidity() {
    hasDetectedValidFace =
    isAcceptableBounds == .detectedFaceAppropriateSizeAndPosition &&
    isAcceptableRoll &&
    isAcceptablePitch &&
    isAcceptableYaw &&
    isAcceptableQuality
  }
}
