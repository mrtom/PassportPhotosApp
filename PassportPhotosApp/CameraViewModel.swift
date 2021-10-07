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
  case noFaceDetected
  case faceObservationDetected(FaceGeometryModel)
}

struct FaceGeometryModel {
  let boundingBox: CGRect
}

final class CameraViewModel: ObservableObject {
  var cancellable: AnyCancellable? // TODO: Set called subscriptions?

  // MARK: - Publishers
  @Published var faceGeometryState: FaceObservation<FaceGeometryModel>

  init() {
    faceGeometryState = .faceNotFound
  }

  // MARK: Actions

  func perform(action: CameraViewModelAction) {
    switch action {
    case .noFaceDetected:
      publishNoFaceObserved()
    case .faceObservationDetected(let faceObservation):
      publishFaceObservation(faceObservation)
    }
  }

  // MARK: Action handlers

  private func publishNoFaceObserved() {
    DispatchQueue.main.async { [self] in
      faceGeometryState = .faceNotFound
    }
  }

  private func publishFaceObservation(_ faceGeometryModel: FaceGeometryModel) {
    DispatchQueue.main.async { [self] in
      faceGeometryState = .faceFound(faceGeometryModel)
    }
//    self.cancellable = tubeLinesStatusFetcher.fetchStatus()
//      .sink(receiveCompletion: asyncCompletionErrorHandler) { allLinesStatus in
//        DispatchQueue.main.async { [self] in
//          let lastUpdatedDisplayValue: String
//          if let updatedDate = allLinesStatus.lastUpdated {
//            lastUpdatedDisplayValue = dateFormatter.string(from: updatedDate)
//          } else {
//            lastUpdatedDisplayValue = "Unknown"
//          }
//
//          tubeStatusState = .loaded(
//            TubeStatusModel(
//              lastUpdated: "Last Updated: \(lastUpdatedDisplayValue)",
//              linesStatus: allLinesStatus.linesStatus.compactMap {
//                LineStatusModel(
//                  id: $0.line.name,
//                  displayName: $0.line.name,
//                  status: $0.status,
//                  color: $0.line.color
//                )
//              })
//          )
//        }
//      }
  }
}
