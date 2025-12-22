//
//  WeightHistoryView.swift
//
//  Weight History screen
//

import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    var body: some View {
        NavigationStack {
            Group {
                if weightEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No weight entries yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start tracking your weight to see your progress here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(weightEntries) { entry in
                            WeightEntryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(entry.weight)) lbs")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(entry.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WeightHistoryView()
        .modelContainer(for: [WeightEntry.self], inMemory: true)
}

