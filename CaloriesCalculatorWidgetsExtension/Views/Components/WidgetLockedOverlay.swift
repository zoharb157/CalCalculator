//
//  WidgetLockedOverlay.swift
//  CaloriesCalculatorWidgets
//
//  Premium lock overlay for widget content (similar to PremiumLockedContent in main app)
//

import SwiftUI
import WidgetKit

/// A locked content wrapper for widget views that shows blur and premium badge when not subscribed
struct WidgetLockedContent<Content: View>: View {
    let isSubscribed: Bool
    let content: Content
    
    init(isSubscribed: Bool, @ViewBuilder content: () -> Content) {
        self.isSubscribed = isSubscribed
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: isSubscribed ? 0 : 8)
                .opacity(isSubscribed ? 1.0 : 0.3)
            
            if !isSubscribed {
                premiumOverlay
            }
        }
    }
    
    private var premiumOverlay: some View {
        VStack(spacing: 10) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                )
            
            // Premium required message
            VStack(spacing: 4) {
                Text("Premium Required")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Upgrade to unlock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Premium badge with crown icon
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Premium")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                // Gold/yellow gradient matching the main app
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.0),  // Gold
                        Color(red: 1.0, green: 0.92, blue: 0.3)   // Lighter gold
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
        )
    }
}

/// Compact premium overlay for accessory widgets (lock screen)
struct WidgetAccessoryLockedContent<Content: View>: View {
    let isSubscribed: Bool
    let content: Content
    
    init(isSubscribed: Bool, @ViewBuilder content: () -> Content) {
        self.isSubscribed = isSubscribed
        self.content = content()
    }
    
    var body: some View {
        if isSubscribed {
            content
        } else {
            ZStack {
                content
                    .blur(radius: 6)
                    .opacity(0.2)
                
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Premium")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Widget Locked - Small") {
    WidgetLockedContent(isSubscribed: false) {
        SmallWidgetView(macros: MockData.midDayProgress)
    }
    .frame(width: 170, height: 170)
    .background(WidgetColors.widgetBackground)
}

#Preview("Widget Unlocked - Small") {
    WidgetLockedContent(isSubscribed: true) {
        SmallWidgetView(macros: MockData.midDayProgress)
    }
    .frame(width: 170, height: 170)
    .background(WidgetColors.widgetBackground)
}

#Preview("Widget Locked - Medium") {
    WidgetLockedContent(isSubscribed: false) {
        MediumWidgetView(macros: MockData.midDayProgress)
    }
    .frame(width: 360, height: 170)
    .background(WidgetColors.widgetBackground)
}
