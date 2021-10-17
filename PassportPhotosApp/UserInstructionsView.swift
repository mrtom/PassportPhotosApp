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

import SwiftUI

struct UserInstructionsView: View {
  @ObservedObject var model: CameraViewModel

  var body: some View {
    Text(faceDetectionStateLabel())
      .font(.title)
  }
}

// MARK: Private instance methods

extension UserInstructionsView {
  func faceDetectionStateLabel() -> String {
    switch model.faceDetectedState {
    case .faceDetectionErrored:
      return "An unexpected error occurred"
    case .noFaceDetected:
      return "Please look at the camera"
    case .faceDetected:
      if model.hasDetectedValidFace {
        return "Please take your photo :]"
      } else if model.isAcceptableBounds == .detectedFaceTooSmall {
        return "Please bring your face closer to the camera"
      } else if model.isAcceptableBounds == .detectedFaceTooLarge {
        return "Please hold the camera further from your face"
      } else if model.isAcceptableBounds == .detectedFaceOffCentre {
        return "Please move your face to the centre of the frame"
      } else if !model.isAcceptableRoll || !model.isAcceptablePitch || !model.isAcceptableYaw {
        return "Please look straight at the camera"
      } else if !model.isAcceptableQuality {
        return "Image quality too low"
      } else {
        return "We cannot take your photo right now"
      }
    }
  }
}

struct UserInstructionsView_Previews: PreviewProvider {
  static var previews: some View {
    UserInstructionsView(
      model: CameraViewModel()
    )
  }
}
