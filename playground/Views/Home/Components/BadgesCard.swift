//
//  BadgesCard.swift
//  playground
//
//  Card displaying badges progress with quick access to badges view
//

import SwiftUI

struct BadgesCard: View {
    @State private var badgeManager = BadgeManager.shared
    let onTap: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var progressValue: Double {
        guard badgeManager.totalBadgeCount > 0 else { return 0 }
        return Double(badgeManager.unlockedBadgeCount) / Double(badgeManager.totalBadgeCount)
    }
    
    private var recentBadges: [EarnedBadge] {
        Array(badgeManager.earnedBadges.sorted { $0.earnedDate > $1.earnedDate }.prefix(3))
    }
    
    private var nextBadgeToEarn: BadgeType? {
        BadgeType.allCases.first { !badgeManager.hasBadge($0) }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header
                headerView
                
                // Badge icons showcase
                badgeShowcaseView
                
                // Progress bar
                progressBarView
                
                // Footer hint
                footerView
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "medal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(localizationManager.localizedString(for: AppStrings.Home.myBadges))
                    .font(.headline)
                    .id("my-badges-\(localizationManager.currentLanguage)")
                    .foregroundColor(.primary)
                
                Text("\(badgeManager.unlockedBadgeCount) of \(badgeManager.totalBadgeCount) earned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Badge Showcase View
    
    @ViewBuilder
    private var badgeShowcaseView: some View {
        HStack(spacing: 16) {
            if recentBadges.isEmpty {
                // Show locked badges hint
                ForEach(0..<3, id: \.self) { index in
                    lockedBadgeIcon(for: BadgeType.allCases[safe: index])
                }
            } else {
                // Show earned badges
                ForEach(recentBadges) { badge in
                    earnedBadgeIcon(badge: badge)
                }
                
                // Fill remaining slots with locked badges
                if recentBadges.count < 3, let nextBadge = nextBadgeToEarn {
                    lockedBadgeIcon(for: nextBadge)
                }
            }
            
            Spacer()
            
            // Show more indicator if there are more badges
            if badgeManager.unlockedBadgeCount > 3 {
                VStack {
                    Text("+\(badgeManager.unlockedBadgeCount - 3)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func earnedBadgeIcon(badge: EarnedBadge) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [badge.type.color.opacity(0.3), badge.type.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: badge.type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [badge.type.color, badge.type.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(badge.type.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 56)
        }
    }
    
    @ViewBuilder
    private func lockedBadgeIcon(for badgeType: BadgeType?) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                if let type = badgeType {
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.4))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            
            Text(badgeType?.displayName ?? "Locked")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 56)
        }
        .opacity(0.6)
    }
    
    // MARK: - Progress Bar View
    
    @ViewBuilder
    private var progressBarView: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressValue, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressValue)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(Int(progressValue * 100))% Complete")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let nextBadge = nextBadgeToEarn {
                    Text("\(localizationManager.localizedString(for: AppStrings.Home.next_)) \(nextBadge.displayName)")
                        .id("next-badge-\(localizationManager.currentLanguage)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Footer View
    
    @ViewBuilder
    private var footerView: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
                Text(localizationManager.localizedString(for: AppStrings.Home.tapToViewBadges))
                    .id("tap-view-badges-\(localizationManager.currentLanguage)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Safe Array Access Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Preview

#Preview("With Badges") {
    VStack {
        BadgesCard {
            print("Tapped")
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack {
        BadgesCard {
            print("Tapped")
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
