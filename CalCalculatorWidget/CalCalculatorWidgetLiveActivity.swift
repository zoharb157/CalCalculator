//
//  CalCalculatorWidgetLiveActivity.swift
//  CalCalculatorWidget
//
//  Live Activity for tracking meal logging sessions
//

import ActivityKit
import WidgetKit
import SwiftUI

#if os(iOS)
/// Attributes for the meal tracking Live Activity
struct CalCalculatorWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var caloriesConsumed: Int
        var caloriesGoal: Int
        var proteinConsumed: Double
        var carbsConsumed: Double
        var fatConsumed: Double
        var mealCount: Int
        var lastMealName: String?
        
        var caloriesRemaining: Int {
            max(0, caloriesGoal - caloriesConsumed)
        }
        
        var progress: Double {
            guard caloriesGoal > 0 else { return 0 }
            return Double(caloriesConsumed) / Double(caloriesGoal)
        }
        
        var isOverGoal: Bool {
            caloriesConsumed > caloriesGoal
        }
    }
    
    var name: String
    var startTime: Date
}

struct CalCalculatorWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalCalculatorWidgetAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(context.state.caloriesConsumed)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.caloriesRemaining)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("left")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Today's Progress")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedProgressView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text("\(context.state.caloriesConsumed)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: min(context.state.progress, 1.0))
                        .stroke(context.state.isOverGoal ? Color.red : Color.green, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            .widgetURL(URL(string: "calcalculator://liveactivity"))
            .keylineTint(Color.orange)
        }
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CalCalculatorWidgetAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(context.state.progress, 1.0))
                    .stroke(
                        context.state.isOverGoal ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(min(context.state.progress, 1.0) * 100))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(context.state.caloriesConsumed)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("/ \(context.state.caloriesGoal) kcal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if let mealName = context.state.lastMealName {
                    Text("Last: \(mealName)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(context.state.caloriesRemaining)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(context.state.isOverGoal ? .red : .green)
                Text("remaining")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Expanded Progress View (Dynamic Island)

struct ExpandedProgressView: View {
    let state: CalCalculatorWidgetAttributes.ContentState
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state.isOverGoal ? Color.red : Color.green)
                        .frame(width: geometry.size.width * min(state.progress, 1.0))
                }
            }
            .frame(height: 8)
            
            // Macros row
            HStack(spacing: 16) {
                MacroLabel(title: "P", value: state.proteinConsumed, color: .orange)
                MacroLabel(title: "C", value: state.carbsConsumed, color: .blue)
                MacroLabel(title: "F", value: state.fatConsumed, color: .purple)
                
                Spacer()
                
                Text("\(state.mealCount) meals")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct MacroLabel: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(title): \(Int(value))g")
                .font(.system(size: 11, weight: .medium))
        }
    }
}

// MARK: - Previews

@available(iOS 16.1, *)
struct CalCalculatorWidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = CalCalculatorWidgetAttributes(name: "Today", startTime: Date())
    static let contentState = CalCalculatorWidgetAttributes.ContentState(
        caloriesConsumed: 1450,
        caloriesGoal: 2000,
        proteinConsumed: 95,
        carbsConsumed: 180,
        fatConsumed: 45,
        mealCount: 3,
        lastMealName: "Grilled Chicken Salad"
    )
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")
        
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Dynamic Island Compact")
        
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Dynamic Island Expanded")
        
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Dynamic Island Minimal")
    }
}
#endif
