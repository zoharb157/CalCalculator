//
//  DataExportView.swift
//  playground
//
//  Export data to PDF format
//

import SwiftUI
import SwiftData
import PDFKit
import SDK

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // User settings for weight units
    private var settings: UserSettings {
        UserSettings.shared
    }
    
    // App name from Bundle
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String 
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String 
            ?? "CalorieVisionAI"
    }
    
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareSheetURL: URL?
    @State private var showShareSheet = false
    @State private var showingPaywall = false
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            List {
                // Weight Data Section
                Section {
                    ExportOptionRow(
                        icon: "scalemass.fill",
                        iconColor: .blue,
                        title: localizationManager.localizedString(for: AppStrings.Profile.weightHistory),
                        subtitle: "\(weightEntries.count) entries",
                        isDisabled: weightEntries.isEmpty
                    ) {
                        if isSubscribed {
                            exportWeightDataPDF()
                        } else {
                            showingPaywall = true
                        }
                    }
                } header: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.weightData))
                } footer: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.exportWeightDescription))
                }
                
                // Meal Data Section
                Section {
                    ExportOptionRow(
                        icon: "fork.knife",
                        iconColor: .green,
                        title: localizationManager.localizedString(for: AppStrings.Profile.mealHistory),
                        subtitle: "\(meals.count) meals logged",
                        isDisabled: meals.isEmpty
                    ) {
                        if isSubscribed {
                            exportMealDataPDF()
                        } else {
                            showingPaywall = true
                        }
                    }
                    
                    ExportOptionRow(
                        icon: "chart.bar.fill",
                        iconColor: .orange,
                        title: localizationManager.localizedString(for: AppStrings.Profile.dailyNutritionSummary),
                        subtitle: localizationManager.localizedString(for: AppStrings.Profile.aggregatedDailyTotals),
                        isDisabled: meals.isEmpty
                    ) {
                        if isSubscribed {
                            exportDailyNutritionSummaryPDF()
                        } else {
                            showingPaywall = true
                        }
                    }
                } header: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.nutritionData))
                } footer: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.exportNutritionDescription))
                }
                
                // Export All Section
                Section {
                    ExportOptionRow(
                        icon: "square.and.arrow.up.fill",
                        iconColor: .purple,
                        title: localizationManager.localizedString(for: AppStrings.Profile.exportAllData),
                        subtitle: localizationManager.localizedString(for: AppStrings.Profile.completeDataBackup),
                        isDisabled: weightEntries.isEmpty && meals.isEmpty
                    ) {
                        if isSubscribed {
                            exportAllDataPDF()
                        } else {
                            showingPaywall = true
                        }
                    }
                } footer: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.exportAllDescription))
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.exportData))
                .id("export-data-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isExporting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(localizationManager.localizedString(for: AppStrings.Profile.generatingPDF))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
            .onChange(of: showShareSheet) { oldValue, newValue in
                if !newValue && oldValue {
                    // Share sheet was dismissed - clean up temporary file immediately
                    if let url = shareSheetURL {
                        try? FileManager.default.removeItem(at: url)
                        shareSheetURL = nil
                    }
                }
            }
            .alert("Export Error", isPresented: .init(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
            } message: {
                Text(exportError ?? localizationManager.localizedString(for: AppStrings.Profile.unknownError))
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareSheetURL {
                    ShareSheet(items: [url])
                }
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                SDKView(
                    model: sdk,
                    page: .splash,
                    show: paywallBinding(showPaywall: $showingPaywall, sdk: sdk),
                    backgroundColor: .white,
                    ignoreSafeArea: true
                )
            }
        }
    }
    
    // MARK: - PDF Export Functions
    
    private func exportWeightDataPDF() {
        isExporting = true
        
        Task { @MainActor in
            let pdfData = generateWeightPDF()
            let filename = "weight_history_\(dateString()).pdf"
            sharePDF(pdfData, filename: filename)
        }
    }
    
    private func exportMealDataPDF() {
        isExporting = true
        
        Task { @MainActor in
            let pdfData = generateMealsPDF()
            let filename = "meal_history_\(dateString()).pdf"
            sharePDF(pdfData, filename: filename)
        }
    }
    
    private func exportDailyNutritionSummaryPDF() {
        isExporting = true
        
        Task { @MainActor in
            let pdfData = generateDailyNutritionPDF()
            let filename = "daily_nutrition_\(dateString()).pdf"
            sharePDF(pdfData, filename: filename)
        }
    }
    
    private func exportAllDataPDF() {
        isExporting = true
        
        Task { @MainActor in
            let pdfData = generateComprehensivePDF()
            // Get app name for filename
            let appNameForFile = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String 
                ?? Bundle.main.infoDictionary?["CFBundleName"] as? String 
                ?? "CalorieVisionAI").lowercased().replacingOccurrences(of: " ", with: "_")
            let filename = "\(appNameForFile)_report_\(dateString()).pdf"
            sharePDF(pdfData, filename: filename)
        }
    }
    
    // MARK: - PDF Generation
    
    private func generateWeightPDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return pdfRenderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            // Title
            yPosition = drawTitle("Weight History Report", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 10
            
            // Date
            yPosition = drawSubtitle("Generated on \(formattedDate(Date()))", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 20
            
            // Summary
            if !weightEntries.isEmpty {
                let latestWeightKg = weightEntries.first?.weight ?? 0
                let startWeightKg = weightEntries.last?.weight ?? 0
                let changeKg = latestWeightKg - startWeightKg
                
                // Convert to display units
                let latestWeight = settings.useMetricUnits ? latestWeightKg : latestWeightKg * 2.20462
                let startWeight = settings.useMetricUnits ? startWeightKg : startWeightKg * 2.20462
                let change = settings.useMetricUnits ? changeKg : changeKg * 2.20462
                let unit = settings.weightUnit
                let changeText = change >= 0 ? "+\(String(format: "%.1f", change))" : String(format: "%.1f", change)
                
                yPosition = drawSummaryBox(
                    items: [
                        ("Total Entries", "\(weightEntries.count)"),
                        ("Current Weight", String(format: "%.1f %@", latestWeight, unit)),
                        ("Starting Weight", String(format: "%.1f %@", startWeight, unit)),
                        ("Total Change", "\(changeText) \(unit)")
                    ],
                    at: yPosition,
                    pageWidth: pageWidth,
                    margin: margin
                )
                yPosition += 30
            }
            
            // Table Header
            let weightUnit = settings.weightUnit
            yPosition = drawTableHeader(
                columns: ["Date", "Weight (\(weightUnit))", "Note"],
                widths: [150, 100, 262],
                at: yPosition,
                margin: margin
            )
            
            // Table Rows
            for entry in weightEntries.reversed() {
                if yPosition > pageHeight - margin - 30 {
                    context.beginPage()
                    yPosition = margin
                }
                
                // Convert weight to display units
                let displayWeight = settings.useMetricUnits ? entry.weight : entry.weight * 2.20462
                
                yPosition = drawTableRow(
                    values: [
                        formattedDate(entry.date),
                        String(format: "%.1f", displayWeight),
                        entry.note ?? "-"
                    ],
                    widths: [150, 100, 262],
                    at: yPosition,
                    margin: margin
                )
            }
        }
    }
    
    private func generateMealsPDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return pdfRenderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            // Title
            yPosition = drawTitle("Meal History Report", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 10
            
            // Date
            yPosition = drawSubtitle("Generated on \(formattedDate(Date()))", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 20
            
            // Summary
            let totalCalories = meals.reduce(0) { $0 + $1.totalCalories }
            let avgCalories = meals.isEmpty ? 0 : totalCalories / meals.count
            
            yPosition = drawSummaryBox(
                items: [
                    ("Total Meals", "\(meals.count)"),
                    ("Total Calories", "\(totalCalories)"),
                    ("Avg per Meal", "\(avgCalories) cal")
                ],
                at: yPosition,
                pageWidth: pageWidth,
                margin: margin
            )
            yPosition += 30
            
            // Table Header
            yPosition = drawTableHeader(
                columns: ["Date", "Meal", "Cal", "P", "C", "F"],
                widths: [90, 180, 50, 50, 50, 50],
                at: yPosition,
                margin: margin
            )
            
            // Table Rows
            for meal in meals.reversed() {
                if yPosition > pageHeight - margin - 30 {
                    context.beginPage()
                    yPosition = margin
                }
                
                yPosition = drawTableRow(
                    values: [
                        formattedShortDate(meal.timestamp),
                        String(meal.name.prefix(25)),
                        "\(meal.totalCalories)",
                        String(format: "%.0f", meal.totalMacros.proteinG),
                        String(format: "%.0f", meal.totalMacros.carbsG),
                        String(format: "%.0f", meal.totalMacros.fatG)
                    ],
                    widths: [90, 180, 50, 50, 50, 50],
                    at: yPosition,
                    margin: margin
                )
            }
        }
    }
    
    private func generateDailyNutritionPDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
        // Group meals by date
        var dailyData: [String: (calories: Int, protein: Double, carbs: Double, fat: Double, mealCount: Int)] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for meal in meals {
            let dateKey = dateFormatter.string(from: meal.timestamp)
            let existing = dailyData[dateKey] ?? (0, 0, 0, 0, 0)
            dailyData[dateKey] = (
                existing.calories + meal.totalCalories,
                existing.protein + meal.totalMacros.proteinG,
                existing.carbs + meal.totalMacros.carbsG,
                existing.fat + meal.totalMacros.fatG,
                existing.mealCount + 1
            )
        }
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return pdfRenderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin
            
            // Title
            yPosition = drawTitle("Daily Nutrition Summary", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 10
            
            // Date
            yPosition = drawSubtitle("Generated on \(formattedDate(Date()))", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 20
            
            // Summary
            let totalDays = dailyData.count
            let avgCalories = dailyData.isEmpty ? 0 : dailyData.values.reduce(0) { $0 + $1.calories } / totalDays
            
            yPosition = drawSummaryBox(
                items: [
                    ("Days Tracked", "\(totalDays)"),
                    ("Avg Daily Calories", "\(avgCalories)")
                ],
                at: yPosition,
                pageWidth: pageWidth,
                margin: margin
            )
            yPosition += 30
            
            // Table Header
            yPosition = drawTableHeader(
                columns: ["Date", "Calories", "Protein", "Carbs", "Fat", "Meals"],
                widths: [100, 80, 80, 80, 80, 60],
                at: yPosition,
                margin: margin
            )
            
            // Table Rows
            let sortedDates = dailyData.keys.sorted()
            for date in sortedDates {
                if let data = dailyData[date] {
                    if yPosition > pageHeight - margin - 30 {
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    yPosition = drawTableRow(
                        values: [
                            date,
                            "\(data.calories)",
                            String(format: "%.0fg", data.protein),
                            String(format: "%.0fg", data.carbs),
                            String(format: "%.0fg", data.fat),
                            "\(data.mealCount)"
                        ],
                        widths: [100, 80, 80, 80, 80, 60],
                        at: yPosition,
                        margin: margin
                    )
                }
            }
        }
    }
    
    private func generateComprehensivePDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return pdfRenderer.pdfData { context in
            // Cover Page
            context.beginPage()
            var yPosition: CGFloat = pageHeight / 3
            
            // App Title - Get from Bundle
            let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String 
                ?? Bundle.main.infoDictionary?["CFBundleName"] as? String 
                ?? "CalorieVisionAI"
            let titleFont = UIFont.boldSystemFont(ofSize: 36)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemBlue
            ]
            let titleSize = appName.size(withAttributes: titleAttributes)
            appName.draw(
                at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: yPosition),
                withAttributes: titleAttributes
            )
            yPosition += 50
            
            // Report Title
            yPosition = drawTitle("Complete Data Report", at: yPosition, pageWidth: pageWidth, margin: margin)
            yPosition += 20
            yPosition = drawSubtitle("Generated on \(formattedDate(Date()))", at: yPosition, pageWidth: pageWidth, margin: margin)
            
            // Summary Stats on Cover
            yPosition += 60
            yPosition = drawSummaryBox(
                items: [
                    ("Weight Entries", "\(weightEntries.count)"),
                    ("Meals Logged", "\(meals.count)")
                ],
                at: yPosition,
                pageWidth: pageWidth,
                margin: margin
            )
            
            // Weight History Section
            if !weightEntries.isEmpty {
                context.beginPage()
                yPosition = margin
                
                yPosition = drawSectionTitle("Weight History", at: yPosition, pageWidth: pageWidth, margin: margin)
                yPosition += 20
                
                let weightUnit = settings.weightUnit
                yPosition = drawTableHeader(
                    columns: ["Date", "Weight (\(weightUnit))", "Note"],
                    widths: [150, 100, 262],
                    at: yPosition,
                    margin: margin
                )
                
                for entry in weightEntries.reversed().prefix(50) {
                    if yPosition > pageHeight - margin - 30 {
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    // Convert weight to display units
                    let displayWeight = settings.useMetricUnits ? entry.weight : entry.weight * 2.20462
                    
                    yPosition = drawTableRow(
                        values: [
                            formattedDate(entry.date),
                            String(format: "%.1f", displayWeight),
                            entry.note ?? "-"
                        ],
                        widths: [150, 100, 262],
                        at: yPosition,
                        margin: margin
                    )
                }
            }
            
            // Meal History Section
            if !meals.isEmpty {
                context.beginPage()
                yPosition = margin
                
                yPosition = drawSectionTitle("Recent Meals", at: yPosition, pageWidth: pageWidth, margin: margin)
                yPosition += 20
                
                yPosition = drawTableHeader(
                    columns: ["Date", "Meal", "Cal", "P", "C", "F"],
                    widths: [90, 180, 50, 50, 50, 50],
                    at: yPosition,
                    margin: margin
                )
                
                for meal in meals.reversed().prefix(100) {
                    if yPosition > pageHeight - margin - 30 {
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    yPosition = drawTableRow(
                        values: [
                            formattedShortDate(meal.timestamp),
                            String(meal.name.prefix(25)),
                            "\(meal.totalCalories)",
                            String(format: "%.0f", meal.totalMacros.proteinG),
                            String(format: "%.0f", meal.totalMacros.carbsG),
                            String(format: "%.0f", meal.totalMacros.fatG)
                        ],
                        widths: [90, 180, 50, 50, 50, 50],
                        at: yPosition,
                        margin: margin
                    )
                }
            }
        }
    }
    
    // MARK: - PDF Drawing Helpers
    
    private func drawTitle(_ text: String, at y: CGFloat, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 24)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: y), withAttributes: attributes)
        return y + size.height
    }
    
    private func drawSectionTitle(_ text: String, at y: CGFloat, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 20)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.systemBlue
        ]
        text.draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
        return y + 30
    }
    
    private func drawSubtitle(_ text: String, at y: CGFloat, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: y), withAttributes: attributes)
        return y + size.height
    }
    
    private func drawSummaryBox(items: [(String, String)], at y: CGFloat, pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let boxWidth = pageWidth - (margin * 2)
        let boxHeight: CGFloat = 60
        let boxRect = CGRect(x: margin, y: y, width: boxWidth, height: boxHeight)
        
        // Draw box background
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemGray6.cgColor)
        context?.fill(boxRect)
        context?.setStrokeColor(UIColor.systemGray4.cgColor)
        context?.stroke(boxRect)
        
        // Draw items
        let itemWidth = boxWidth / CGFloat(items.count)
        for (index, item) in items.enumerated() {
            let x = margin + (itemWidth * CGFloat(index)) + (itemWidth / 2)
            
            // Label
            let labelFont = UIFont.systemFont(ofSize: 10)
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: UIColor.secondaryLabel]
            let labelSize = item.0.size(withAttributes: labelAttrs)
            item.0.draw(at: CGPoint(x: x - labelSize.width / 2, y: y + 12), withAttributes: labelAttrs)
            
            // Value
            let valueFont = UIFont.boldSystemFont(ofSize: 16)
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: UIColor.label]
            let valueSize = item.1.size(withAttributes: valueAttrs)
            item.1.draw(at: CGPoint(x: x - valueSize.width / 2, y: y + 30), withAttributes: valueAttrs)
        }
        
        return y + boxHeight
    }
    
    private func drawTableHeader(columns: [String], widths: [CGFloat], at y: CGFloat, margin: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        // Draw header background
        let totalWidth = widths.reduce(0, +)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemBlue.cgColor)
        context?.fill(CGRect(x: margin, y: y, width: totalWidth, height: 20))
        
        // Draw column headers
        var x = margin + 5
        for (index, column) in columns.enumerated() {
            column.draw(at: CGPoint(x: x, y: y + 4), withAttributes: attributes)
            x += widths[index]
        }
        
        return y + 20
    }
    
    private func drawTableRow(values: [String], widths: [CGFloat], at y: CGFloat, margin: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 9)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        
        // Draw row background (alternating)
        let totalWidth = widths.reduce(0, +)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemGray6.cgColor)
        context?.fill(CGRect(x: margin, y: y, width: totalWidth, height: 18))
        
        // Draw border
        context?.setStrokeColor(UIColor.systemGray5.cgColor)
        context?.stroke(CGRect(x: margin, y: y, width: totalWidth, height: 18))
        
        // Draw values
        var x = margin + 5
        for (index, value) in values.enumerated() {
            let truncated = String(value.prefix(Int(widths[index] / 6)))
            truncated.draw(at: CGPoint(x: x, y: y + 3), withAttributes: attributes)
            x += widths[index]
        }
        
        return y + 18
    }
    
    // MARK: - Helpers
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: date)
    }
    
    private func sharePDF(_ data: Data, filename: String) {
        guard !data.isEmpty else {
            DispatchQueue.main.async {
                isExporting = false
                exportError = "Failed to generate PDF. The data is empty."
            }
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            
            // Verify file was written
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                throw NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "File was not created successfully"])
            }
            
            DispatchQueue.main.async {
                isExporting = false
                shareFile(tempURL)
            }
        } catch {
            DispatchQueue.main.async {
                isExporting = false
                exportError = "Failed to export PDF: \(error.localizedDescription)"
                print("❌ Export error: \(error)")
            }
        }
    }
    
    private func shareFile(_ url: URL) {
        shareSheetURL = url
        showShareSheet = true
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Export Option Row

struct ExportOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "doc.fill")
                    .font(.body)
                    .foregroundColor(isDisabled ? .gray.opacity(0.5) : .red)
            }
            .padding(.vertical, 4)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    DataExportView()
        .modelContainer(for: [WeightEntry.self, Meal.self], inMemory: true)
}
