//
//  HealthInfoSourcesView.swift
//  playground
//
//  Displays scientific sources and citations for health information used in the app
//

import SwiftUI

/// View displaying scientific sources and citations for health-related calculations
/// Required by Apple App Store Review Guidelines 1.4.1 for apps containing health/medical information
struct HealthInfoSourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Disclaimer
                    disclaimerSection
                    
                    // BMR Calculation
                    sourceSection(
                        title: "Basal Metabolic Rate (BMR)",
                        description: "We calculate your daily calorie needs using the Harris-Benedict equation, a widely-used formula in nutrition science.",
                        reference: "Harris JA, Benedict FG. \"A Biometric Study of Human Basal Metabolism.\" Proceedings of the National Academy of Sciences. 1918;4(12):370-373.",
                        url: "https://doi.org/10.1073/pnas.4.12.370"
                    )
                    
                    // Activity Multipliers
                    sourceSection(
                        title: "Activity Level Multipliers (TDEE)",
                        description: "Total Daily Energy Expenditure is calculated by multiplying BMR with activity factors based on established research.",
                        reference: "Mifflin MD, St Jeor ST, et al. \"A new predictive equation for resting energy expenditure in healthy individuals.\" American Journal of Clinical Nutrition. 1990;51(2):241-247.",
                        url: "https://doi.org/10.1093/ajcn/51.2.241"
                    )
                    
                    // BMI Categories
                    sourceSection(
                        title: "Body Mass Index (BMI) Categories",
                        description: "BMI classifications used in this app follow the World Health Organization's international standards.",
                        reference: "World Health Organization. \"Body mass index - BMI.\" WHO European Regional Office.",
                        url: "https://www.who.int/europe/news-room/fact-sheets/item/a-healthy-lifestyle---who-recommendations",
                        additionalInfo: """
                        BMI Categories:
                        • Underweight: < 18.5
                        • Normal weight: 18.5 - 24.9
                        • Overweight: 25.0 - 29.9
                        • Obese: ≥ 30.0
                        """
                    )
                    
                    // Macronutrient Energy Values
                    sourceSection(
                        title: "Macronutrient Energy Values",
                        description: "Calorie calculations for protein, carbohydrates, and fat are based on standard nutritional science values.",
                        reference: "USDA Food Composition Databases. National Agricultural Library.",
                        url: "https://www.nal.usda.gov/fnic/how-many-calories-are-one-gram-fat-carbohydrate-or-protein",
                        additionalInfo: """
                        Energy per gram:
                        • Protein: 4 kcal/g
                        • Carbohydrates: 4 kcal/g
                        • Fat: 9 kcal/g
                        """
                    )
                    
                    // Safe Calorie Deficit
                    sourceSection(
                        title: "Safe Weight Loss Guidelines",
                        description: "Our recommended calorie deficit for weight loss follows evidence-based guidelines for safe, sustainable weight management.",
                        reference: "American College of Sports Medicine. Position Stand on Appropriate Physical Activity Intervention Strategies for Weight Loss.",
                        url: "https://www.acsm.org",
                        additionalInfo: """
                        Recommendations:
                        • Weight loss: 500 kcal/day deficit (~1 lb/week)
                        • Weight gain: 300 kcal/day surplus
                        • Minimum intake: 1,200 kcal/day
                        """
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Health Information Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Disclaimer Section
    
    @ViewBuilder
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Important Notice")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("This app provides general nutritional information based on established scientific research. The calculations and recommendations are for informational purposes only and should not replace professional medical advice, diagnosis, or treatment. Always consult with a qualified healthcare provider before making significant changes to your diet or exercise routine.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Source Section
    
    @ViewBuilder
    private func sourceSection(
        title: String,
        description: String,
        reference: String,
        url: String,
        additionalInfo: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let info = additionalInfo {
                Text(info)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(reference)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: {
                    if let linkURL = URL(string: url) {
                        UIApplication.shared.open(linkURL)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text("View Source")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    HealthInfoSourcesView()
}
