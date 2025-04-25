import SwiftUI

struct ProfileSelectionView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingCreateProfile = false
    @State private var selectedProfile: Profile?
    @State private var pinInput = ""
    @State private var showingPinPrompt = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 50), count: 3)
    
    var body: some View {
        VStack {
            Text("Who's Watching?")
                .font(.largeTitle)
                .padding(.top, 60)
            
            LazyVGrid(columns: columns, spacing: 50) {
                ForEach(profileManager.profiles) { profile in
                    ProfileButton(profile: profile) {
                        if let pin = profile.pin, !pin.isEmpty {
                            selectedProfile = profile
                            showingPinPrompt = true
                        } else {
                            profileManager.currentProfile = profile
                        }
                    }
                }
                
                // Add Profile Button
                Button(action: { showingCreateProfile = true }) {
                    VStack {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        Text("Add Profile")
                            .font(.title2)
                    }
                }
                .buttonStyle(.plain)
                .focusable()
            }
            .padding(.horizontal, 100)
            .padding(.vertical, 50)
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView()
        }
        .alert("Enter PIN", isPresented: $showingPinPrompt) {
            SecureField("PIN", text: $pinInput)
                .keyboardType(.numberPad)
            Button("OK") {
                if let profile = selectedProfile, profile.pin == pinInput {
                    profileManager.currentProfile = profile
                }
                pinInput = ""
            }
            Button("Cancel", role: .cancel) {
                pinInput = ""
            }
        }
    }
}

struct ProfileButton: View {
    let profile: Profile
    let action: () -> Void
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 120, height: 120)
                    
                    Text(profile.name.prefix(2).uppercased())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(profile.name)
                    .font(.title2)
                
                if profile.pin != nil {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusable()
    }
}

struct CreateProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    
    @State private var name = ""
    @State private var pin = ""
    @State private var usePin = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Create Profile")
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.headline)
                TextField("Enter profile name", text: $name)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(10)
                    .frame(maxWidth: 400)
            }
            
            Toggle("Use PIN Protection", isOn: $usePin)
                .frame(maxWidth: 400)
            
            if usePin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PIN (4 digits)")
                        .font(.headline)
                    SecureField("Enter PIN", text: $pin)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .frame(maxWidth: 400)
                        .keyboardType(.numberPad)
                }
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    let newProfile = Profile(
                        name: name,
                        pin: usePin ? pin : nil
                    )
                    profileManager.profiles.append(newProfile)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || (usePin && pin.count != 4))
            }
        }
        .padding(50)
    }
}

// MARK: - Preview
struct ProfileSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSelectionView()
            .environmentObject(ProfileManager())
    }
} 