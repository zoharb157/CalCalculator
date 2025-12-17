//
//  ConfidenceIndicator.swift
//  playground
//
//  Results view - Confidence level indicator
//

import SwiftUI

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 12) {
            confidenceIcon
            
            VStack(alignment: .leading, spacing: 2) {
                confidenceLabel
                confidenceBar
            }
            
            Spacer()
            
            percentageBadge
        }
        .padding()
        .background(confidenceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Private Views
    
    private var confidenceIcon: some View {
        ZStack {
            Circle()
                .fill(confidenceColor.opacity(0.2))
                .frame(width: 36, height: 36)
            
            Image(systemName: confidenceIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(confidenceColor)
        }
    }
    
    private var confidenceLabel: some View {
        Text(confidenceTextString)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.primary)
    }
    
    private var confidenceBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(confidenceColor)
                    .frame(width: geometry.size.width * confidence, height: 4)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 100)
    }
    
    private var percentageBadge: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(confidenceColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor.opacity(0.15))
            .clipShape(Capsule())
    }
    
    // MARK: - Computed Properties
    
    private var confidenceTextString: String {
        if confidence >= 0.8 {
            return "High Confidence"
        } else if confidence >= 0.6 {
            return "Medium Confidence"
        } else {
            return "Low Confidence"
        }
    }
    
    private var confidenceIconName: String {
        if confidence >= 0.8 {
            return "checkmark.seal.fill"
        } else if confidence >= 0.6 {
            return "chart.bar.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ConfidenceIndicator(confidence: 0.9)
        ConfidenceIndicator(confidence: 0.7)
        ConfidenceIndicator(confidence: 0.5)
    }
    .padding()
}
