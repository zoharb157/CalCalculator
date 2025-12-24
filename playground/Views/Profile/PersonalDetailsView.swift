//
//  PersonalDetailsView.swift
//  playground
//
//  Personal Details editing screen with beautiful UI
//

import SwiftUI
import PhotosUI

struct PersonalDetailsView: View {
    
    // MARK: - Properties
    
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Editing states
    @State private var isEditingWeight = false
    @State private var isEditingGoalWeight = false
    @State private var isEditingHeight = false
    @State private var isEditingDateOfBirth = false
    @State private var isEditingGender = false
    @State private var isEditingStepGoal = false
    @State private var isEditingName = false
    @State private var isEditingUsername = false
    
    // Profile photo states
    @State private var showingPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    
    // Temporary edit values
    @State private var tempWeight: Double = 0
    @State private var tempGoalWeight: Double = 0
    @State private var tempHeightFeet: Int = 5
    @State private var tempHeightInches: Int = 8
    @State private var tempDateOfBirth: Date = Date()
    @State private var tempGender: Gender = .male
    @State private var tempStepGoal: Int = 10000
    @State private var tempFirstName: String = ""
    @State private var tempLastName: String = ""
    @State private var tempUsername: String = ""
    
    private let imageStorage = ImageStorage.shared
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeaderSection
                    metricsSection
                    goalsSection
                    activitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Personal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentValues()
                loadProfileImage()
            }
        }
        .sheet(isPresented: $isEditingName) {
            editNameSheet
        }
        .sheet(isPresented: $isEditingWeight) {
            editWeightSheet
        }
        .sheet(isPresented: $isEditingGoalWeight) {
            editGoalWeightSheet
        }
        .sheet(isPresented: $isEditingHeight) {
            editHeightSheet
        }
        .sheet(isPresented: $isEditingDateOfBirth) {
            editDateOfBirthSheet
        }
        .sheet(isPresented: $isEditingGender) {
            editGenderSheet
        }
        .sheet(isPresented: $isEditingStepGoal) {
            editStepGoalSheet
        }
        .sheet(isPresented: $isEditingUsername) {
            editUsernameSheet
        }
        .confirmationDialog("Change Profile Photo", isPresented: $showingPhotoOptions) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Choose from Library") {
                showingImagePicker = true
            }
            if profileImage != nil {
                Button("Remove Photo", role: .destructive) {
                    removeProfilePhoto()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let newValue,
                   let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        saveProfilePhoto(image)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ProfilePhotoCameraView { image in
                saveProfilePhoto(image)
            }
        }
    }
    
    // MARK: - Profile Header Section
    
    @ViewBuilder
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Avatar with photo picker
            Button {
                showingPhotoOptions = true
            } label: {
                ZStack {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(initials)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Camera badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 100, height: 100)
                }
            }
            .buttonStyle(.plain)
            
            // Name
            VStack(spacing: 4) {
                Text(viewModel.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Button {
                    tempUsername = viewModel.username
                    isEditingUsername = true
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.username.isEmpty ? "Set username" : "@\(viewModel.username)")
                            .font(.subheadline)
                            .foregroundColor(viewModel.username.isEmpty ? .secondary : .primary)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Edit Name Button
            Button {
                tempFirstName = viewModel.firstName
                tempLastName = viewModel.lastName
                isEditingName = true
            } label: {
                Text("Edit Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Metrics Section
    
    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Body Metrics")
            
            ProfileSectionCard {
                // Current Weight
                EditableDetailRow(
                    icon: "scalemass.fill",
                    iconColor: .blue,
                    label: "Current Weight",
                    value: viewModel.currentWeightDisplay
                ) {
                    tempWeight = viewModel.currentWeight
                    isEditingWeight = true
                }
                
                SettingsDivider()
                
                // Height
                EditableDetailRow(
                    icon: "ruler.fill",
                    iconColor: .green,
                    label: "Height",
                    value: viewModel.heightDisplay
                ) {
                    tempHeightFeet = viewModel.heightFeet
                    tempHeightInches = viewModel.heightInches
                    isEditingHeight = true
                }
                
                SettingsDivider()
                
                // Date of Birth
                EditableDetailRow(
                    icon: "calendar",
                    iconColor: .orange,
                    label: "Date of Birth",
                    value: formattedDateOfBirth
                ) {
                    tempDateOfBirth = viewModel.dateOfBirth
                    isEditingDateOfBirth = true
                }
                
                SettingsDivider()
                
                // Gender
                EditableDetailRow(
                    icon: "person.fill",
                    iconColor: .purple,
                    label: "Gender",
                    value: viewModel.gender.displayName
                ) {
                    tempGender = viewModel.gender
                    isEditingGender = true
                }
            }
            
            // BMI Card
            bmiCard
        }
    }
    
    // MARK: - Goals Section
    
    @ViewBuilder
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Weight Goal")
            
            ProfileSectionCard {
                EditableDetailRow(
                    icon: "flag.fill",
                    iconColor: .red,
                    label: "Goal Weight",
                    value: viewModel.goalWeightDisplay
                ) {
                    tempGoalWeight = viewModel.goalWeight
                    isEditingGoalWeight = true
                }
            }
            
            // Progress indicator
            weightProgressCard
        }
    }
    
    // MARK: - Activity Section
    
    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: "Activity")
            
            ProfileSectionCard {
                EditableDetailRow(
                    icon: "figure.walk",
                    iconColor: .cyan,
                    label: "Daily Step Goal",
                    value: "\(viewModel.dailyStepGoal.formatted()) steps"
                ) {
                    tempStepGoal = viewModel.dailyStepGoal
                    isEditingStepGoal = true
                }
            }
        }
    }
    
    // MARK: - BMI Card
    
    @ViewBuilder
    private var bmiCard: some View {
        HStack(spacing: 16) {
            // BMI Value
            VStack(alignment: .leading, spacing: 4) {
                Text("BMI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f", viewModel.bmi))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(viewModel.bmiColor)
            }
            
            Spacer()
            
            // BMI Category
            VStack(alignment: .trailing, spacing: 4) {
                Text("Category")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(viewModel.bmiCategory)
                    .font(.headline)
                    .foregroundColor(viewModel.bmiColor)
            }
        }
        .padding(16)
        .background(viewModel.bmiColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Weight Progress Card
    
    @ViewBuilder
    private var weightProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to Goal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(weightDifferenceText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
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
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Edit Sheets
    
    @ViewBuilder
    private var editNameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $tempFirstName)
                    TextField("Last Name", text: $tempLastName)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingName = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.firstName = tempFirstName
                        viewModel.lastName = tempLastName
                        isEditingName = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editWeightSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(Int(tempWeight)) lbs")
                    .font(.system(size: 48, weight: .bold))
                
                Slider(value: $tempWeight, in: 80...400, step: 1)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Current Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingWeight = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.currentWeight = tempWeight
                        isEditingWeight = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editGoalWeightSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(Int(tempGoalWeight)) lbs")
                    .font(.system(size: 48, weight: .bold))
                
                Slider(value: $tempGoalWeight, in: 80...400, step: 1)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Goal Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingGoalWeight = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.goalWeight = tempGoalWeight
                        isEditingGoalWeight = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editHeightSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(tempHeightFeet) ft \(tempHeightInches) in")
                    .font(.system(size: 48, weight: .bold))
                
                HStack(spacing: 24) {
                    // Feet picker
                    VStack {
                        Text("Feet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Feet", selection: $tempHeightFeet) {
                            ForEach(4...7, id: \.self) { feet in
                                Text("\(feet)").tag(feet)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                    
                    // Inches picker
                    VStack {
                        Text("Inches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Inches", selection: $tempHeightInches) {
                            ForEach(0...11, id: \.self) { inches in
                                Text("\(inches)").tag(inches)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingHeight = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.heightFeet = tempHeightFeet
                        viewModel.heightInches = tempHeightInches
                        isEditingHeight = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editDateOfBirthSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "Date of Birth",
                    selection: $tempDateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingDateOfBirth = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.dateOfBirth = tempDateOfBirth
                        isEditingDateOfBirth = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editGenderSheet: some View {
        NavigationStack {
            List {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Button {
                        tempGender = gender
                    } label: {
                        HStack {
                            Text(gender.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if tempGender == gender {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingGender = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.gender = tempGender
                        isEditingGender = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editStepGoalSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(tempStepGoal.formatted()) steps")
                    .font(.system(size: 36, weight: .bold))
                
                Slider(
                    value: Binding(
                        get: { Double(tempStepGoal) },
                        set: { tempStepGoal = Int($0) }
                    ),
                    in: 1000...30000,
                    step: 500
                )
                .padding(.horizontal, 32)
                
                // Quick select buttons
                HStack(spacing: 12) {
                    ForEach([5000, 8000, 10000, 12000], id: \.self) { goal in
                        Button {
                            tempStepGoal = goal
                        } label: {
                            Text("\(goal / 1000)k")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(tempStepGoal == goal ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(tempStepGoal == goal ? Color.blue : Color.blue.opacity(0.15))
                                .cornerRadius(20)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Daily Step Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingStepGoal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.dailyStepGoal = tempStepGoal
                        isEditingStepGoal = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @ViewBuilder
    private var editUsernameSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $tempUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Username")
                } footer: {
                    Text("Your username will be displayed as @\(tempUsername.isEmpty ? "username" : tempUsername)")
                }
            }
            .navigationTitle("Edit Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingUsername = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.username = tempUsername.lowercased().replacingOccurrences(of: " ", with: "")
                        isEditingUsername = false
                        HapticManager.shared.notification(.success)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helpers
    
    private var initials: String {
        let components = viewModel.fullName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return initials.isEmpty ? "?" : String(initials).uppercased()
    }
    
    private var formattedDateOfBirth: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: viewModel.dateOfBirth)
    }
    
    private var weightDifferenceText: String {
        let difference = abs(viewModel.currentWeight - viewModel.goalWeight)
        if viewModel.currentWeight > viewModel.goalWeight {
            return "\(Int(difference)) lbs to lose"
        } else if viewModel.currentWeight < viewModel.goalWeight {
            return "\(Int(difference)) lbs to gain"
        }
        return "Goal reached!"
    }
    
    private var progressPercentage: CGFloat {
        // Simple progress calculation - you might want to improve this
        let difference = abs(viewModel.currentWeight - viewModel.goalWeight)
        let maxDifference: Double = 100 // Assume max 100 lbs difference for full scale
        return max(0, min(1, CGFloat(1 - difference / maxDifference)))
    }
    
    private func loadCurrentValues() {
        tempWeight = viewModel.currentWeight
        tempGoalWeight = viewModel.goalWeight
        tempHeightFeet = viewModel.heightFeet
        tempHeightInches = viewModel.heightInches
        tempDateOfBirth = viewModel.dateOfBirth
        tempGender = viewModel.gender
        tempStepGoal = viewModel.dailyStepGoal
        tempFirstName = viewModel.firstName
        tempLastName = viewModel.lastName
        tempUsername = viewModel.username
    }
    
    private func loadProfileImage() {
        profileImage = imageStorage.loadProfilePhoto()
    }
    
    private func saveProfilePhoto(_ image: UIImage) {
        // Resize image if needed
        let resizedImage = resizeImage(image, targetSize: CGSize(width: 400, height: 400))
        
        do {
            _ = try imageStorage.saveProfilePhoto(resizedImage)
            profileImage = resizedImage
            HapticManager.shared.notification(.success)
        } catch {
            print("Failed to save profile photo: \(error)")
        }
    }
    
    private func removeProfilePhoto() {
        imageStorage.deleteProfilePhoto()
        profileImage = nil
        HapticManager.shared.notification(.success)
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

// MARK: - Profile Photo Camera View

struct ProfilePhotoCameraView: UIViewControllerRepresentable {
    var onPhotoTaken: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfilePhotoCameraView
        
        init(_ parent: ProfilePhotoCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onPhotoTaken(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    PersonalDetailsView(viewModel: ProfileViewModel())
}
