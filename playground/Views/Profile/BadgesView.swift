//
//  BadgesView.swift
//  playground
//
//  View to display all badges (earned and locked)
//

import SwiftUI

struct BadgesView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    @State private var badgeManager = BadgeManager.shared
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    progressHeader
                    badgesGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.myBadges))
                .id("my-badges-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .id("done-badges-\(localizationManager.currentLanguage)")
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Progress Header
    
    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 12) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progressValue)
                
                VStack(spacing: 2) {
                    Text("\(badgeManager.unlockedBadgeCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("of \(badgeManager.totalBadgeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            
            Text("Badges Earned")
                .font(.headline)
                .foregroundColor(.primary)
            
            if badgeManager.unlockedBadgeCount == badgeManager.totalBadgeCount {
                Text("Congratulations! You've earned all badges!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Keep logging to unlock more badges!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Badges Grid
    
    @ViewBuilder
    private var badgesGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Badges")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(BadgeType.allCases, id: \.self) { badgeType in
                    BadgeCard(
                        badgeType: badgeType,
                        earnedBadge: badgeManager.earnedBadges.first { $0.type == badgeType }
                    )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progressValue: CGFloat {
        guard badgeManager.totalBadgeCount > 0 else { return 0 }
        return CGFloat(badgeManager.unlockedBadgeCount) / CGFloat(badgeManager.totalBadgeCount)
    }
}

// MARK: - Badge Card

struct BadgeCard: View {
    let badgeType: BadgeType
    let earnedBadge: EarnedBadge?
    
    var isEarned: Bool {
        earnedBadge != nil
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isEarned
                            ? LinearGradient(
                                colors: [badgeType.color.opacity(0.3), badgeType.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: badgeType.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(
                        isEarned
                            ? LinearGradient(
                                colors: [badgeType.color, badgeType.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            }
            
            // Badge Name
            Text(badgeType.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isEarned ? .primary : .secondary)
                .lineLimit(1)
            
            // Description or Earned Date
            if let earned = earnedBadge {
                Text("Earned \(formattedDate(earned.earnedDate))")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .lineLimit(1)
            } else {
                Text(badgeType.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isEarned ? badgeType.color.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .opacity(isEarned ? 1.0 : 0.7)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    BadgesView()
}
