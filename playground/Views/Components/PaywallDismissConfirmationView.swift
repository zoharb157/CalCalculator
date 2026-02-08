import SwiftUI

struct PaywallDismissConfirmationView: View {
    let onStay: () -> Void
    let onLeave: () -> Void
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = 0
    
    private let premiumFeatures: [(icon: String, titleKey: String)] = [
        ("infinity", "Paywall.feature.unlimitedScans"),
        ("chart.line.uptrend.xyaxis", "Paywall.feature.advancedProgress"),
        ("list.clipboard", "Paywall.feature.dietPlans"),
        ("doc.text", "Paywall.feature.pdfExport"),
        ("apps.iphone", "Paywall.feature.premiumWidgets")
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { }
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.2), .red.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(iconRotation))
                    }
                    
                    Text(localizationManager.localizedString(for: "Paywall.dismiss.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(localizationManager.localizedString(for: "Paywall.dismiss.subtitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 28)
                .padding(.bottom, 20)
                
                VStack(spacing: 12) {
                    ForEach(premiumFeatures, id: \.icon) { feature in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: feature.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            
                            Text(localizationManager.localizedString(for: feature.titleKey))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                VStack(spacing: 12) {
                    Button(action: onStay) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text(localizationManager.localizedString(for: "Paywall.dismiss.stayButton"))
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    
                    Button(action: onLeave) {
                        Text(localizationManager.localizedString(for: "Paywall.dismiss.leaveButton"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.25), radius: 24)
            )
            .padding(.horizontal, 24)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                    iconRotation = -10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        iconRotation = 0
                    }
                }
            }
        }
    }
}

#Preview {
    PaywallDismissConfirmationView(
        onStay: { print("Stay") },
        onLeave: { print("Leave") }
    )
}
