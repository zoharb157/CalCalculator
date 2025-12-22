//
//  PDFSummaryReportView.swift
//
//  PDF Summary Report screen
//

import SwiftUI

struct PDFSummaryReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingNext = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Illustration
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 200, height: 200)
                        
                        HStack(spacing: -20) {
                            ReportCardPreview(color: .blue)
                            ReportCardPreview(color: .green)
                            ReportCardPreview(color: .orange)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Title
                    Text("Get your PDF Summary Report")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Here's what you'll get in your summary report:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 20) {
                        ReportFeature(
                            icon: "fork.knife",
                            title: "Meal history",
                            description: "All logged meals and nutrition details"
                        )
                        
                        ReportFeature(
                            icon: "figure.run",
                            title: "Exercise history",
                            description: "Logged workouts and activity sessions"
                        )
                        
                        ReportFeature(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Weight progress",
                            description: "Weekly trend of recorded weight changes"
                        )
                        
                        ReportFeature(
                            icon: "clock.arrow.circlepath",
                            title: "Calorie & macros breakdown",
                            description: "Historical breakdown of calories and macros"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Next Button
                    Button {
                        showingNext = true
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("PDF Summary Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNext) {
                PDFGenerationView()
            }
        }
    }
}

struct ReportCardPreview: View {
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.3))
            .frame(width: 80, height: 100)
            .overlay(
                VStack {
                    Text("Cal AI")
                        .font(.caption2)
                    Spacer()
                }
                .padding(4)
            )
            .rotationEffect(.degrees(Double.random(in: -5...5)))
    }
}

struct ReportFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PDFGenerationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                ProgressView()
                Text("Generating PDF...")
                    .padding()
            }
            .navigationTitle("Generating Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    PDFSummaryReportView()
}

