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
                .blur(radius: isSubscribed ? 0 : 6)
                .opacity(isSubscribed ? 1.0 : 0.4)
            
            if !isSubscribed {
                premiumOverlay
            }
        }
    }
    
    private var premiumOverlay: some View {
        VStack(spacing: 8) {
            // Premium badge with crown icon
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Premium")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
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
            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
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
                    .blur(radius: 4)
                    .opacity(0.3)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
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
