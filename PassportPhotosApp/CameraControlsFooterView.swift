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

struct CameraControlsFooterView: View {
  @ObservedObject var model: CameraViewModel

  @State private var isShowingPassportPhoto = false

  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color.black.opacity(0.8))
      HStack(spacing: 20) {
        Spacer()
        Button(action: {
          model.perform(action: .toggleDebugMode)
        }, label: {
          FooterIconView(imageName: "ladybug.fill")
        })
        .tint(model.debugModeEnabled ? .green : .gray)
        Spacer()
        Button(action: {
          model.perform(action: .takePhoto)
        }, label: {
          FooterIconView(imageName: "camera.aperture")
        })
          .disabled(model.hasDetectedValidFace ? false : true)
          .tint(.white)
        Spacer()
        if let photo = model.passportPhoto {
          VStack {
            NavigationLink(
              destination: PassportPhotoView(passportPhoto: photo),
              isActive: $isShowingPassportPhoto
            ) {
              EmptyView()
            }
            Button(action: {
              isShowingPassportPhoto = true
            }, label: {
              Image(uiImage: photo)
                .resizable()
                .frame(width: 45.0, height: 60.0)
          })
          }
        } else {
          FooterIconView(imageName: "photo.fill.on.rectangle.fill")
        }
        Spacer()
      }
    }
  }

  struct FooterIconView: View {
    var imageName: String

    var body: some View {
      return Image(systemName: imageName)
        .font(.system(size: 36))
    }
  }
}

struct CameraControlsFooterView_Previews: PreviewProvider {
  static var previews: some View {
    CameraControlsFooterView(model: CameraViewModel())
  }
}
