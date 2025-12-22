//
//  FeatureRequestsView.swift
//
//  Feature Requests screen
//

import SwiftUI

struct FeatureRequestsView: View {
    @State private var selectedFilter: FilterType = .mostVoted
    @State private var searchText = ""
    @State private var showingCreate = false
    
    var filteredRequests: [FeatureRequest] {
        let filtered = searchText.isEmpty ? featureRequests : featureRequests.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .mostVoted:
            return filtered.sorted { $0.votes > $1.votes }
        case .newest:
            return filtered.sorted { $0.date > $1.date }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter
                Picker("Filter", selection: $selectedFilter) {
                    Text("Most Voted").tag(FilterType.mostVoted)
                    Text("Newest").tag(FilterType.newest)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search feature requests...", text: $searchText)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // List
                List(filteredRequests) { request in
                    FeatureRequestRow(request: request)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Feature Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Create")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateFeatureRequestView()
            }
        }
    }
}

enum FilterType {
    case mostVoted
    case newest
}

struct FeatureRequestRow: View {
    let request: FeatureRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.title)
                .font(.headline)
            
            Text(request.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("\(request.comments)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("\(request.votes)")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct FeatureRequest: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let votes: Int
    let comments: Int
    let date: Date
}

let featureRequests: [FeatureRequest] = [
    FeatureRequest(title: "Recurring meals", description: "It would be great to be able to copy today's meal to tomorrow. I do a lot o...", votes: 1972, comments: 125, date: Date()),
    FeatureRequest(title: "Protein suggestions", description: "It was be great if we could receive protein suggestions when we are...", votes: 1729, comments: 68, date: Date().addingTimeInterval(-86400)),
    FeatureRequest(title: "Sync with activity app", description: "Sync the workout", votes: 1528, comments: 177, date: Date().addingTimeInterval(-172800)),
    FeatureRequest(title: "Please sync with Apple Health", description: "Or Hume Scale", votes: 1400, comments: 54, date: Date().addingTimeInterval(-259200)),
    FeatureRequest(title: "Recommend foods based on macros goals", description: "Suggest foods that help meet daily macro targets", votes: 1092, comments: 89, date: Date().addingTimeInterval(-345600))
]

struct CreateFeatureRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $description)
                    .frame(height: 200)
            }
            .navigationTitle("Create Feature Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FeatureRequestsView()
}

