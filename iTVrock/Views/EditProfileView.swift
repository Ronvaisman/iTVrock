import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    
    let profile: Profile
    
    @State private var name: String
    @State private var isParentalControlEnabled: Bool
    @State private var allowedContentRating: String
    @State private var pin: String
    @State private var error: String?
    
    private let contentRatings = ["G", "PG", "PG-13", "R", "NC-17"]
    
    init(profile: Profile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        _isParentalControlEnabled = State(initialValue: profile.isParentalControlEnabled)
        _allowedContentRating = State(initialValue: profile.allowedContentRating)
        _pin = State(initialValue: profile.pin ?? "")
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Edit Profile")
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Name")
                        .font(.headline)
                    TextField("Profile Name", text: $name)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 300)
                }
                
                Toggle("Enable Parental Controls", isOn: $isParentalControlEnabled)
                    .frame(maxWidth: 300)
                
                if isParentalControlEnabled {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Content Rating")
                            .font(.headline)
                        
                        HStack {
                            ForEach(contentRatings, id: \.self) { rating in
                                Button(action: { allowedContentRating = rating }) {
                                    Text(rating)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(allowedContentRating == rating ? Color.accentColor : Color.secondary.opacity(0.2))
                                        )
                                        .foregroundColor(allowedContentRating == rating ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .focusable(true)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PIN")
                                .font(.headline)
                            SecureField("Enter 4-digit PIN", text: $pin)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(10)
                                .frame(maxWidth: 200)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(50)
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var isValid: Bool {
        if name.isEmpty { return false }
        if isParentalControlEnabled {
            if pin.count != 4 || !pin.allSatisfy({ $0.isNumber }) {
                return false
            }
        }
        return true
    }
    
    private func saveChanges() {
        guard isValid else { return }
        
        // Create updated profile
        var updatedProfile = profile
        updatedProfile.name = name
        updatedProfile.isParentalControlEnabled = isParentalControlEnabled
        updatedProfile.allowedContentRating = allowedContentRating
        updatedProfile.pin = isParentalControlEnabled ? pin : nil
        
        // Update in manager
        if let index = profileManager.profiles.firstIndex(where: { $0.id == profile.id }) {
            profileManager.profiles[index] = updatedProfile
            dismiss()
        } else {
            error = "Failed to update profile"
        }
    }
}

// MARK: - Preview
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(profile: Profile(
            name: "Test Profile",
            avatarIndex: 0,
            pin: "1234",
            isParentalControlEnabled: true,
            allowedContentRating: "PG-13"
        ))
        .environmentObject(ProfileManager())
    }
} 