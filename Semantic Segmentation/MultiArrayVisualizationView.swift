//
//  MultiArrayVisualizationView.swift
//  Semantic Segmentation
//
//  Created by Kristian Emil on 23/12/2024.
//


import SwiftUI

struct SegmentationColors {
    static let names = ["--", "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train",
        "truck", "boat", "traffic light", "fire hydrant", "--", "stop sign",
        "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
        "elephant", "bear", "zebra", "giraffe", "--", "backpack", "umbrella"]
    
    static let colors: [Color] = [
        .clear,      // background
        .red,        // person
        .blue,       // bicycle
        .yellow,     // car
        .orange,     // motorcycle
        .purple,     // airplane
        .red,        // bus
        .blue,       // train
        .yellow,     // truck
        .cyan,       // boat
        .red,        // traffic light
        .orange,     // fire hydrant
        .clear,      // --
        .red,        // stop sign
        .blue,       // parking meter
        .brown,      // bench
        .green,      // bird
        .orange,     // cat
        .brown,      // dog
        .brown,      // horse
        .white,      // sheep
        .brown,      // cow
        .gray,      // elephant
        .brown,      // bear
        .white,      // zebra
        .yellow,     // giraffe
        .clear,      // --
        .purple,     // backpack
        .blue,       // umbrella
    ]
}

struct MultiArrayVisualizationView: View {
    let matrix: [[Float]]
    
    func getColor(for value: Float) -> Color {
        let normalized = Double((value + 1) / 2)  // Convert Float to Double
        return Color(red: normalized, green: normalized, blue: normalized)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(
                geometry.size.width / CGFloat(matrix[0].count),
                geometry.size.height / CGFloat(matrix.count)
            )
            
            ScrollView([.horizontal, .vertical]) {
                Canvas { context, size in
                    for (i, row) in matrix.enumerated() {
                        for (j, value) in row.enumerated() {
                            let rect = CGRect(
                                x: CGFloat(j) * cellSize,
                                y: CGFloat(i) * cellSize,
                                width: cellSize,
                                height: cellSize
                            )
                            context.fill(Path(rect), with: .color(getColor(for: value)))
                        }
                    }
                }
                .frame(
                    width: CGFloat(matrix[0].count) * cellSize,
                    height: CGFloat(matrix.count) * cellSize
                )
            }
        }
    }
}

struct ResultsView: View {
    let matrix: [[Float]]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Segmentation Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            MultiArrayVisualizationView(matrix: matrix)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Class legend
            VStack(alignment: .leading, spacing: 8) {
                Text("Classes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(zip(0..<29, SegmentationColors.names)), id: \.0) { index, name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(SegmentationColors.colors[index])
                                .frame(width: 12, height: 12)
                            Text(name)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - StatisticRow View
//struct StatisticRow: View {
//    let label: String
//    let value: Float
//    
//    var body: some View {
//        HStack {
//            Text(label)
//                .foregroundColor(.secondary)
//            Spacer()
//            Text(String(format: "%.3f", value))
//                .foregroundColor(.primary)
//                .fontWeight(.medium)
//        }
//    }
//}
