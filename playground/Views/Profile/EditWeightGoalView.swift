//
//  EditWeightGoalView.swift
//  playground
//
//  Edit Weight Goal screen with ruler slider
//

import SwiftUI

struct EditWeightGoalView: View {
    @State private var profile = UserProfile.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeight: Double
    @State private var goalType: String = "Lose weight"
    
    init() {
        _selectedWeight = State(initialValue: UserProfile.shared.goalWeight)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Goal Type
                Text(goalType)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Weight Display
                Text("\(selectedWeight, format: .number.precision(.fractionLength(1))) lbs")
                    .font(.system(size: 48, weight: .bold))
                
                // Ruler Slider
                WeightRulerSlider(
                    value: $selectedWeight,
                    range: 80...250,
                    step: 0.1
                )
                .frame(height: 100)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profile.goalWeight = selectedWeight
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WeightRulerSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * 0.6)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: geometry.size.width * 0.4)
                }
                
                // Ruler marks
                HStack(spacing: 0) {
                    ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: 5)), id: \.self) { mark in
                        VStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: mark.truncatingRemainder(dividingBy: 10) == 0 ? 2 : 1,
                                       height: mark.truncatingRemainder(dividingBy: 10) == 0 ? 20 : 10)
                            Spacer()
                        }
                        .frame(width: geometry.size.width / CGFloat((range.upperBound - range.lowerBound) / 5))
                    }
                }
                
                // Selection indicator
                let position = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 3, height: 30)
                    .offset(x: position - 1.5)
                
                // Drag gesture
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let newValue = range.lowerBound + Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                                value = min(max(newValue, range.lowerBound), range.upperBound)
                            }
                    )
            }
        }
    }
}

#Preview {
    EditWeightGoalView()
}

