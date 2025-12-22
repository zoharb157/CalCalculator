//
//  ProfileView.swift
//  playground
//
//  Main Profile/Settings screen matching the design
//

import SwiftUI

struct ProfileView: View {
    @State private var profile = UserProfile.shared
    @State private var showingPersonalDetails = false
    @State private var showingPreferences = false
    @State private var showingLanguageSelection = false
    @State private var showingEditNutritionGoals = false
    @State private var showingEditWeightGoal = false
    @State private var showingWeightHistory = false
    @State private var showingRingColorsExplained = false
    @State private var showingReferFriend = false
    @State private var showingMilestones = false
    @State private var showingFeatureRequests = false
    @State private var showingSupportEmail = false
    @State private var showingPDFSummary = false
    @State private var showingWidgets = false
    @State private var showingFamilyPlan = false
    @State private var showingPremium = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Info Card
                    profileInfoCard
                    
                    // App Theme Section
                    appThemeSection
                    
                    // Premium Section
                    premiumSection
                    
                    // Invite Friends Section
                    inviteFriendsSection
                    
                    // Account Section
                    accountSection
                    
                    // Goals & Tracking Section
                    goalsTrackingSection
                    
                    // Support & Legal Section
                    supportLegalSection
                    
                    // Follow Us Section
                    followUsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for tab bar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPersonalDetails) {
            PersonalDetailsView()
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingEditNutritionGoals) {
            EditNutritionGoalsView()
        }
        .sheet(isPresented: $showingEditWeightGoal) {
            EditWeightGoalView()
        }
        .sheet(isPresented: $showingWeightHistory) {
            WeightHistoryView()
        }
        .sheet(isPresented: $showingRingColorsExplained) {
            RingColorsExplainedView()
        }
        .sheet(isPresented: $showingReferFriend) {
            ReferFriendView()
        }
        .sheet(isPresented: $showingMilestones) {
            MilestonesView()
        }
        .sheet(isPresented: $showingFeatureRequests) {
            FeatureRequestsView()
        }
        .sheet(isPresented: $showingSupportEmail) {
            SupportEmailView()
        }
        .sheet(isPresented: $showingPDFSummary) {
            PDFSummaryReportView()
        }
        .sheet(isPresented: $showingWidgets) {
            WidgetsView()
        }
        .sheet(isPresented: $showingFamilyPlan) {
            FamilyPlanView()
        }
        .fullScreenCover(isPresented: $showingPremium) {
            PremiumView()
        }
    }
    
    // MARK: - Profile Info Card
    private var profileInfoCard: some View {
        Button {
            showingPersonalDetails = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if profile.username.isEmpty {
                        Text("and username")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("@\(profile.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - App Theme Section
    private var appThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Theme")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feel the Holiday Magic")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Let your app sparkle with snow and Christmas cheer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(false))
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Premium Section
    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Button {
                showingPremium = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try Premium for Free")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Unlock Cal AI free for 7 days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Invite Friends Section
    private var inviteFriendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Friends")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Button {
                showingReferFriend = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refer a friend and earn $10")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Earn $10 per friend that signs up with your promo code.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.text.rectangle",
                    title: "Personal Details",
                    action: { showingPersonalDetails = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "gearshape",
                    title: "Preferences",
                    action: { showingPreferences = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "textformat.abc",
                    title: "Language",
                    action: { showingLanguageSelection = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "person.2",
                    title: "Upgrade to Family Plan",
                    action: { showingFamilyPlan = true }
                )
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Goals & Tracking Section
    private var goalsTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals & Tracking")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "target",
                    title: "Edit Nutrition Goals",
                    action: { showingEditNutritionGoals = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "flag",
                    title: "Goals & current weight",
                    action: { showingEditWeightGoal = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    title: "Weight History",
                    action: { showingWeightHistory = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "target",
                    title: "Ring Colors Explained",
                    action: { showingRingColorsExplained = true }
                )
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Support & Legal Section
    private var supportLegalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support & Legal")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "megaphone",
                    title: "Request a Feature",
                    action: { showingFeatureRequests = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "envelope",
                    title: "Support Email",
                    action: { showingSupportEmail = true }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "square.and.arrow.up",
                    title: "Export PDF Summary Report",
                    action: { showingPDFSummary = true }
                )
                
                Divider().padding(.leading, 60)
                
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Sync Data")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Last Synced: 2:55 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Sync action
                }
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "doc.text",
                    title: "Terms and Conditions",
                    action: { /* Open terms */ }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "checkmark.shield",
                    title: "Privacy Policy",
                    action: { /* Open privacy */ }
                )
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Follow Us Section
    private var followUsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow Us")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "camera",
                    title: "Instagram",
                    action: { /* Open Instagram */ }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "music.note",
                    title: "TikTok",
                    action: { /* Open TikTok */ }
                )
                
                Divider().padding(.leading, 60)
                
                SettingsRow(
                    icon: "xmark",
                    title: "X",
                    action: { /* Open X/Twitter */ }
                )
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileView()
}

