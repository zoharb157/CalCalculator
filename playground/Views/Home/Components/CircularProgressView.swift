//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI


struct CircularProgressView: View {
    let progress: Double
    
    private var progressGradient: AngularGradient {
        if progress > 1 {
            return AngularGradient(
                gradient: Gradient(colors: [.red, .pink]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        } else if progress >= 0.8 {
            return AngularGradient(
                gradient: Gradient(colors: [.green, .mint]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        } else if progress >= 0.5 {
            return AngularGradient(
                gradient: Gradient(colors: [.orange, .yellow]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        } else {
            return AngularGradient(
                gradient: Gradient(colors: [.blue, .cyan]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
        }
    }
    
    private var ringShadowColor: Color {
        if progress > 1 { return .red }
        else if progress >= 0.8 { return .green }
        else if progress >= 0.5 { return .orange }
        else { return .blue }
    }
    
    var body: some View {
        ZStack {
            // Background circle with depth
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 12)
            
            // Progress circle with gradient and shadow
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringShadowColor.opacity(0.3), radius: 5, x: 0, y: 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
            
            // Percentage text with modern typography
            VStack(spacing: 0) {
                Text("\(Int(round(min(progress, 1.0) * 100)))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                
                if progress > 1.0 {
                    Text("+\(Int(round((progress - 1.0) * 100)))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.top, 2)
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
