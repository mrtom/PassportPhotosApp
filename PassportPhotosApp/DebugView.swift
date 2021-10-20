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

struct DebugView: View {
  @ObservedObject var model: CameraViewModel

  var body: some View {
    ZStack {
      FaceBoundingBoxView(model: model)
      FaceLayoutGuideView(model: model)
      VStack(alignment: .leading, spacing: 5) {
        DebugSection(observation: model.faceGeometryState) { _ in
          DebugText("Debug")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct DebugSection<Model, Content: View>: View {
  let observation: FaceObservation<Model>
  let content: (Model) -> Content

  public init(
    observation: FaceObservation<Model>,
    @ViewBuilder content: @escaping (Model) -> Content
  ) {
    self.observation = observation
    self.content = content
  }

  var body: some View {
    switch observation {
    case .faceNotFound:
      AnyView(Spacer())
    case .faceFound(let model):
      AnyView(content(model))
    case .errored(let error):
      AnyView(
        DebugText("ERROR: \(error.localizedDescription)")
      )
    }
  }
}

enum DebugTextStatus {
  case neutral
  case failing
  case passing
}

struct DebugText: View {
  let content: String

  @inlinable
  public init(_ content: String) {
    self.content = content
  }

  var body: some View {
    Text(content)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct Status: ViewModifier {
  let foregroundColor: Color

  func body(content: Content) -> some View {
    content
      .foregroundColor(foregroundColor)
  }
}

extension DebugText {
  func colorForStatus(status: DebugTextStatus) -> Color {
    switch status {
    case .neutral:
      return .white
    case .failing:
      return .red
    case .passing:
      return .green
    }
  }

  func debugTextStatus(status: DebugTextStatus) -> some View {
    self.modifier(Status(foregroundColor: colorForStatus(status: status)))
  }
}

struct DebugView_Previews: PreviewProvider {
  static var previews: some View {
    DebugView(model: CameraViewModel())
  }
}
