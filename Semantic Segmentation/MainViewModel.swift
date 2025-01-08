//
//  MainViewModel.swift
//  Semantic Segmentation
//
//  Created by Kristian Emil on 23/12/2024.
//


import SwiftUI
import CoreML
import Vision
import UIKit

class MainViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    let processor = MultiArrayProcessor()
    
    func processImage(_ image: UIImage) {
        selectedImage = image
        processor.processImage(image)
    }
}
