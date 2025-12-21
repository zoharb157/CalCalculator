//
//  HomeView.swift
//  playground
//
//  CalAI Clone - Main home screen
//

import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let repository: MealRepository
    @Bindable var scanViewModel: ScanViewModel
    var onMealSaved: () -> Void
    
    private var settings = UserSettings.shared
    
    @State private var showScanSheet = false
    
    init(
        viewModel: HomeViewModel,
        repository: MealRepository,
        scanViewModel: ScanViewModel,
        onMealSaved: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.repository = repository
        self.scanViewModel = scanViewModel
        self.onMealSaved = onMealSaved
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                floatingAddButton
            }
            .navigationTitle("Today")
            .navigationDestination(for: UUID.self) { mealId in
                MealDetailView(mealId: mealId, repository: repository)
            }
            .refreshable {
                await viewModel.refreshTodayData()
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showScanSheet) {
                ScanView(
                    viewModel: scanViewModel,
                    onMealSaved: {
                        showScanSheet = false
                        onMealSaved()
                    },
                    onDismiss: {
                        showScanSheet = false
                    }
                )
            }
        }
    }
    
    // MARK: - Private Views
    
    private var contentView: some View {
        List {
            weekDaysSection
            progressSection
            macroSection
            mealsSection
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showScanSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var weekDaysSection: some View {
        WeekDaysHeader(weekDays: viewModel.weekDays)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    private var progressSection: some View {
        TodaysProgressCard(
            summary: viewModel.todaysSummary,
            calorieGoal: settings.calorieGoal,
            remainingCalories: viewModel.remainingCalories,
            progress: viewModel.calorieProgress
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private var macroSection: some View {
        MacroCardsSection(
            summary: viewModel.todaysSummary,
            goals: settings.macroGoals
        )
        .listRowInsets(EdgeInsets(.zero))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var mealsSection: some View {
        Group {
            if !viewModel.recentMeals.isEmpty {
                RecentMealsSection(
                    meals: viewModel.recentMeals,
                    repository: repository,
                    onDelete: { meal in
                        Task {
                            await viewModel.deleteMeal(meal)
                        }
                    }
                )
            } else {
                EmptyMealsView()
                    .listRowInsets(EdgeInsets(top: 40, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HomeViewModel(repository: repository, imageStorage: .shared)
    let scanViewModel = ScanViewModel(
        repository: repository,
        analysisService: CaloriesAPIService(),
        imageStorage: .shared
    )
    
    HomeView(
        viewModel: viewModel,
        repository: repository,
        scanViewModel: scanViewModel,
        onMealSaved: {}
    )
}
