//
//  ProfileComponents.swift
//  playground
//
//  Reusable components for Profile views
//

import SwiftUI

// MARK: - Settings Row

/// A standardized row for settings/profile navigation items
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color = .blue,
        title: String,
        subtitle: String? = nil,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Section Header

struct ProfileSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.footnote)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 8)
    }
}

// MARK: - Profile Section Card

struct ProfileSectionCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }
    
    private var cardBackgroundColor: Color {
        Color(UIColor.secondarySystemGroupedBackground)
    }
}

// MARK: - Editable Detail Row

/// A row that displays editable profile details
struct EditableDetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var isEditing: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                
                // Label and Value
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Edit indicator
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle Setting Row

/// A row with a toggle for boolean settings
struct ToggleSettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Weight Unit Toggle Row

/// A row for toggling between metric (kg) and imperial (lbs) weight units
struct WeightUnitToggleRow: View {
    @Binding var useMetricUnits: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "scalemass")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(localizationManager.localizedString(for: AppStrings.Profile.weightUnits))
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(useMetricUnits 
                     ? localizationManager.localizedString(for: AppStrings.Profile.metricUnits)
                     : localizationManager.localizedString(for: AppStrings.Profile.imperialUnits))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Segmented control style toggle
            Picker("", selection: $useMetricUnits) {
                Text("kg").tag(true)
                Text("lbs").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Profile Info Card

/// The user profile card at the top of the profile screen
struct ProfileInfoCard: View {
    let fullName: String
    let username: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(initials(from: fullName))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                // Name and username
                VStack(alignment: .leading, spacing: 4) {
                    Text(fullName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(username.isEmpty ? LocalizationManager.shared.localizedString(for: AppStrings.Profile.setUsername) : "@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func initials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return initials.isEmpty ? "?" : String(initials).uppercased()
    }
}

// MARK: - Divider Row

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 60)
    }
}

// MARK: - Appearance Mode Selector

struct AppearanceModeSelector: View {
    @Binding var selectedMode: AppearanceMode
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                AppearanceModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode
                ) {
                    selectedMode = mode
                }
            }
        }
    }
}

struct AppearanceModeButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        Button(action: action) {
            VStack(spacing: 8) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(backgroundColor)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    
                    if mode == .system {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white)
                            Rectangle()
                                .fill(Color.black)
                        }
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Label
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.caption)
                    Text(mode.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .id("appearance-mode-\(mode.rawValue)-\(localizationManager.currentLanguage)")
                }
                .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch mode {
        case .system: return Color.clear
        case .light: return Color.white
        case .dark: return Color.black
        }
    }
    
    private var iconName: String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Nutrition Goal Row

struct NutritionGoalCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Int
    let unit: String
    let progress: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(iconColor.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(iconColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(value) \(unit)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Handle iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = .any
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    @Previewable let localizationManager = LocalizationManager.shared
    return ScrollView {
        VStack(spacing: 16) {
            ProfileInfoCard(
                fullName: "John Doe",
                username: "johndoe",
                onTap: {}
            )
            
            ProfileSectionCard {
                SettingsRow(icon: "person.text.rectangle", title: localizationManager.localizedString(for: AppStrings.Profile.personalDetails), action: {})
                SettingsDivider()
                SettingsRow(icon: "gearshape", title: localizationManager.localizedString(for: AppStrings.Profile.preferences), action: {})
            }
            
            ProfileSectionCard {
                EditableDetailRow(
                    icon: "scalemass",
                    iconColor: .blue,
                    label: localizationManager.localizedString(for: AppStrings.Profile.currentWeight),
                    value: "150 lbs",
                    onTap: {}
                )
            }
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
}
