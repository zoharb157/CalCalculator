//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI


struct CircularProgressView: View {
    let progress: Double
    
    private var progressColor: Color {
        if progress > 1 {
            return .red
        } else if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .black
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
            
            // Percentage text
            VStack(spacing: 2) {
                Text("\(Int(min(progress, 1.0) * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                if progress > 1.0 {
                    Text("+\(Int((progress - 1.0) * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview("Normal Progress") {
    CircularProgressView(progress: 0.65)
        .frame(width: 100, height: 100)
        .padding()
}

#Preview("Over Goal") {
    CircularProgressView(progress: 1.25)
        .frame(width: 100, height: 100)
        .padding()
}

#Preview("Near Goal") {
    CircularProgressView(progress: 0.95)
        .frame(width: 100, height: 100)
        .padding()
}
