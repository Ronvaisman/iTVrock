import SwiftUI

struct TVGuideView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var selectedDate = Date()
    @State private var timeSlotWidth: CGFloat = 200
    @State private var selectedProgram: Program?
    @State private var searchText = ""
    
    private let timeSlotDuration: TimeInterval = 30 * 60 // 30 minutes
    private let rowHeight: CGFloat = 80
    private let timeSlots = 24 // Show 12 hours worth of programs
    
    private var filteredChannels: [Channel] {
        if searchText.isEmpty {
            return playlistManager.channels
        }
        return playlistManager.channels.filter { channel in
            channel.name.localizedCaseInsensitiveContains(searchText) ||
            channel.category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Guide Header
            GuideHeader(
                selectedDate: $selectedDate,
                searchText: $searchText
            )
            .padding()
            
            // Time Scale
            TimeScaleView(
                startTime: Calendar.current.startOfDay(for: selectedDate),
                slotWidth: timeSlotWidth,
                slotDuration: timeSlotDuration,
                numberOfSlots: timeSlots
            )
            
            // Guide Grid
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    ForEach(filteredChannels) { channel in
                        ChannelRow(
                            channel: channel,
                            startTime: Calendar.current.startOfDay(for: selectedDate),
                            slotWidth: timeSlotWidth,
                            slotDuration: timeSlotDuration,
                            numberOfSlots: timeSlots,
                            rowHeight: rowHeight,
                            onProgramSelected: { program in
                                selectedProgram = program
                            }
                        )
                        Divider()
                    }
                }
            }
        }
        .sheet(item: $selectedProgram) { program in
            ProgramDetailView(program: program)
        }
    }
}

struct GuideHeader: View {
    @Binding var selectedDate: Date
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            // Date Selection
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                
                Text(selectedDate.formatted(.dateTime.day().month().year()))
                    .font(.title2)
                
                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                
                Button("Today") {
                    selectedDate = Date()
                }
                .padding(.leading)
            }
            
            Spacer()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Channels", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(10)
                    .frame(width: 200)
            }
        }
    }
    
    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct TimeScaleView: View {
    let startTime: Date
    let slotWidth: CGFloat
    let slotDuration: TimeInterval
    let numberOfSlots: Int
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<numberOfSlots, id: \.self) { index in
                        if let time = Calendar.current.date(byAdding: .minute,
                                                          value: Int(slotDuration/60) * index,
                                                          to: startTime) {
                            Text(time.formatted(.dateTime.hour()))
                                .frame(width: slotWidth)
                                .id(index)
                        }
                    }
                }
            }
            .onAppear {
                // Scroll to current time
                let currentHour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(currentHour * 2, anchor: .center)
            }
        }
    }
}

struct ChannelRow: View {
    let channel: Channel
    let startTime: Date
    let slotWidth: CGFloat
    let slotDuration: TimeInterval
    let numberOfSlots: Int
    let rowHeight: CGFloat
    let onProgramSelected: (Program) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Channel Info
            ChannelInfo(channel: channel)
                .frame(width: 200, height: rowHeight)
            
            // Programs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<numberOfSlots, id: \.self) { index in
                        if let slotTime = Calendar.current.date(byAdding: .minute,
                                                              value: Int(slotDuration/60) * index,
                                                              to: startTime),
                           let program = findProgram(at: slotTime) {
                            ProgramCell(program: program, onSelect: onProgramSelected)
                                .frame(width: calculateProgramWidth(program))
                                .frame(height: rowHeight)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: slotWidth, height: rowHeight)
                        }
                    }
                }
            }
        }
    }
    
    private func findProgram(at time: Date) -> Program? {
        channel.currentProgram // TODO: Implement actual program finding logic
    }
    
    private func calculateProgramWidth(_ program: Program) -> CGFloat {
        let duration = program.endTime.timeIntervalSince(program.startTime)
        let slots = duration / slotDuration
        return slotWidth * slots
    }
}

struct ChannelInfo: View {
    let channel: Channel
    
    var body: some View {
        HStack {
            if let logoUrl = channel.logoUrl {
                AsyncImage(url: URL(string: logoUrl)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } placeholder: {
                    Image(systemName: "tv")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "tv")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            
            Text(channel.name)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.secondary.opacity(0.1))
    }
}

struct ProgramCell: View {
    let program: Program
    let onSelect: (Program) -> Void
    @State private var isFocused = false
    
    var body: some View {
        Button(action: { onSelect(program) }) {
            VStack(alignment: .leading) {
                Text(program.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let category = program.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(program.startTime.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(isFocused ? Color.secondary.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(true)
        .onLongPressGesture(minimumDuration: 0.01) {
            withAnimation {
                isFocused = true
            }
        }
    }
}

struct ProgramDetailView: View {
    let program: Program
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text(program.title)
                        .font(.title)
                    
                    if let category = program.category {
                        Text(category)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            if let description = program.description {
                Text(description)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Start Time")
                        .font(.headline)
                    Text(program.startTime.formatted(.dateTime.hour().minute()))
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("End Time")
                        .font(.headline)
                    Text(program.endTime.formatted(.dateTime.hour().minute()))
                }
            }
            
            if let rating = program.rating {
                Text("Rating: \(rating)")
                    .font(.headline)
            }
            
            if program.isNew {
                Text("New Episode")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Preview
struct TVGuideView_Previews: PreviewProvider {
    static var previews: some View {
        TVGuideView()
            .environmentObject(PlaylistManager())
    }
} 