//
//  BackgroundView.swift
//  Semantic Segmentation
//
//  Created by Kristian Emil on 23/12/2024.
//

import SwiftUI

// MARK: - Background View
struct BackgroundView: View {
    let image: UIImage?
    let isClassifying: Bool
    
    var body: some View {
        ZStack {
            if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: isClassifying ? 20 : 0)
                        .animation(.easeInOut(duration: 0.5), value: isClassifying)
                }
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
}
