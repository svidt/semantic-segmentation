//
//  MultiArrayProcessor.swift
//  Semantic Segmentation
//
//  Created by Kristian Emil on 23/12/2024.
//

import SwiftUI
import CoreML
import Vision

class MultiArrayProcessor: ObservableObject {
    @Published var resultMatrix: [[Float]] = []
    @Published var processingState: ProcessingState = .idle
    
    enum ProcessingState {
        case idle
        case processing
        case completed
        case error(String)
    }
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            processingState = .error("Failed to process image")
            return
        }
        
        processingState = .processing
        
        do {
            guard let model = try? DETRResnet50SemanticSegmentationF16(),
                  let vnModel = try? VNCoreMLModel(for: model.model) else {
                processingState = .error("Failed to load ML model")
                return
            }
            
            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                Swift.print("Request callback started")  // Add this
                if let error = error {
                    Swift.print("Error:", error)
                    self?.processingState = .error(error.localizedDescription)
                    return
                }
                
                guard let results = request.results else {
                    Swift.print("No results")  // Add this
                    return
                }
                
                Swift.print("Results count:", results.count)  // Add this
                
                guard let results = request.results,
                      let observation = results.first as? VNCoreMLFeatureValueObservation,
                      let multiArray = observation.featureValue.multiArrayValue else {
                    return
                }
                
                self?.processMultiArray(multiArray)  // Add this line

                Swift.print("Feature name:", observation.featureName)
                Swift.print("Feature type:", type(of: observation.featureValue))
                Swift.print("Feature shape:", observation.featureValue.multiArrayValue?.shape ?? [])
                Swift.print("Feature dataType:", observation.featureValue.multiArrayValue?.dataType ?? "unknown")
                
                Swift.print("Got multiArray")  // Add this
            }
            
            request.imageCropAndScaleOption = .scaleFit
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            try handler.perform([request])
            
        } catch {
            processingState = .error(error.localizedDescription)
        }
    }
    
    private func processMultiArray(_ multiArray: MLMultiArray) {
        let dimensions = multiArray.shape.map { $0.intValue }
        var matrix = Array(repeating: Array(repeating: Float(0), count: dimensions[1]), count: dimensions[0])
        let int32Pointer = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: multiArray.count)
        
        for y in 0..<dimensions[0] {
            for x in 0..<dimensions[1] {
                let index = y * dimensions[1] + x
                let value = Int32(int32Pointer[index])
                matrix[y][x] = Float(value % 29)  // Ensure value is in 0-28 range
            }
        }
        
        Swift.print("Values range:", matrix.flatMap { $0 }.min() ?? 0, "to", matrix.flatMap { $0 }.max() ?? 0)
        Swift.print("Unique values:", Set(matrix.flatMap { $0 }).sorted())
        
        Swift.print("MultiArray shape:", multiArray.shape)
        Swift.print("MultiArray count:", multiArray.count)
        Swift.print("Expected size for 448x448:", 448 * 448)
    
        DispatchQueue.main.async {
            self.resultMatrix = matrix
            self.processingState = .completed
        }
    }
}
