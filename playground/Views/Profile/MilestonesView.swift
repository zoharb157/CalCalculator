//
//  MilestonesView.swift
//
//  Milestones screen with badges and streaks
//

import SwiftUI

struct MilestonesView: View {
    @State private var dayStreak: Int = 0
    @State private var badgesEarned: Int = 1
    @State private var totalBadges: Int = 36
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Cards
                    HStack(spacing: 16) {
                        StreakSummaryCard(streak: dayStreak)
                        BadgesSummaryCard(earned: badgesEarned, total: totalBadges)
                    }
                    .padding(.horizontal)
                    
                    // Badges Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(badgeData, id: \.id) { badge in
                            BadgeCard(badge: badge, isEarned: badge.id <= badgesEarned)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

struct StreakSummaryCard: View {
    let streak: Int
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text("\(streak)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            Text("Day Streak")
                .font(.headline)
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(streak) days")
                Text("longest streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct BadgesSummaryCard: View {
    let earned: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text("\(earned)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            Text("Badges earned")
                .font(.headline)
            
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.purple)
                Text("\(earned)/\(total) badges")
            }
            .font(.subheadline)
            
            ProgressView(value: Double(earned), total: Double(total))
                .tint(.purple)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct BadgeCard: View {
    let badge: BadgeData
    let isEarned: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if badge.isHexagonal {
                    Hexagon()
                        .fill(isEarned ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                } else {
                    Circle()
                        .fill(isEarned ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                }
                
                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundColor(isEarned ? badge.color : .gray)
            }
            
            Text(badge.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(badge.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct BadgeData {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isHexagonal: Bool
}

let badgeData: [BadgeData] = [
    BadgeData(id: 1, title: "Rookie", description: "3 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 2, title: "Getting Serious", description: "10 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 3, title: "Locked In", description: "50 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 4, title: "Triple Threat", description: "100 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 5, title: "No Days Off", description: "365 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 6, title: "Immortal", description: "1000 day streak", icon: "flame.fill", color: .orange, isHexagonal: true),
    BadgeData(id: 7, title: "Forking Around", description: "Logged", icon: "fork.knife", color: .purple, isHexagonal: false),
    BadgeData(id: 8, title: "Mission: Nutrition", description: "Logged", icon: "leaf.fill", color: .purple, isHexagonal: false),
    BadgeData(id: 9, title: "The Logfather", description: "Logged", icon: "cup.and.saucer.fill", color: .purple, isHexagonal: false)
]

#Preview {
    MilestonesView()
}

