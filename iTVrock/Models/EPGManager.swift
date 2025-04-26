import Foundation

struct EPGChannel: Identifiable {
    let id: String // tvg-id or xmltv id
    let displayName: String
    let iconUrl: String?
}

struct EPGProgram: Identifiable {
    let id: String // unique: channel+start
    let channelId: String
    let title: String
    let desc: String?
    let category: String?
    let start: Date
    let stop: Date
}

class EPGManager: ObservableObject {
    @Published var channels: [EPGChannel] = []
    @Published var programs: [EPGProgram] = []
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss Z"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    func fetchAndParse(from url: URL, completion: @escaping (Bool) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { DispatchQueue.main.async { completion(false) }; return }
            self.parse(xmlData: data, completion: completion)
        }.resume()
    }
    
    func parse(xmlData: Data, completion: @escaping (Bool) -> Void) {
        let parser = XMLTVParser(dateFormatter: dateFormatter)
        parser.parse(data: xmlData) { channels, programs in
            DispatchQueue.main.async {
                self.channels = channels
                self.programs = programs
                completion(true)
            }
        }
    }
    
    func programs(for channelId: String, on date: Date) -> [EPGProgram] {
        programs.filter { $0.channelId == channelId && $0.start <= date && $0.stop > date }
    }
}

// --- XMLTVParser ---
class XMLTVParser: NSObject, XMLParserDelegate {
    private let dateFormatter: DateFormatter
    private var channels: [EPGChannel] = []
    private var programs: [EPGProgram] = []
    private var currentElement: String = ""
    private var currentChannel: EPGChannel?
    private var currentProgram: [String: String] = [:]
    private var currentProgramStart: Date?
    private var currentProgramStop: Date?
    private var currentProgramId: String?
    private var currentProgramTitle: String?
    private var currentProgramDesc: String?
    private var currentProgramCategory: String?
    private var currentProgramChannel: String?
    private var completion: (([EPGChannel], [EPGProgram]) -> Void)?
    
    init(dateFormatter: DateFormatter) {
        self.dateFormatter = dateFormatter
    }
    
    func parse(data: Data, completion: @escaping ([EPGChannel], [EPGProgram]) -> Void) {
        self.completion = completion
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "channel" {
            let id = attributeDict["id"] ?? UUID().uuidString
            currentChannel = EPGChannel(id: id, displayName: "", iconUrl: nil)
        } else if elementName == "programme" {
            currentProgramChannel = attributeDict["channel"]
            if let startStr = attributeDict["start"], let start = dateFormatter.date(from: startStr) {
                currentProgramStart = start
            }
            if let stopStr = attributeDict["stop"], let stop = dateFormatter.date(from: stopStr) {
                currentProgramStop = stop
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch currentElement {
        case "display-name":
            if var channel = currentChannel {
                channel = EPGChannel(id: channel.id, displayName: channel.displayName + trimmed, iconUrl: channel.iconUrl)
                currentChannel = channel
            }
        case "icon":
            if var channel = currentChannel {
                channel = EPGChannel(id: channel.id, displayName: channel.displayName, iconUrl: trimmed)
                currentChannel = channel
            }
        case "title":
            currentProgramTitle = (currentProgramTitle ?? "") + trimmed
        case "desc":
            currentProgramDesc = (currentProgramDesc ?? "") + trimmed
        case "category":
            currentProgramCategory = (currentProgramCategory ?? "") + trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "channel" {
            if let channel = currentChannel {
                channels.append(channel)
            }
            currentChannel = nil
        } else if elementName == "programme" {
            if let channelId = currentProgramChannel, let start = currentProgramStart, let stop = currentProgramStop, let title = currentProgramTitle {
                let id = channelId + "-" + String(Int(start.timeIntervalSince1970))
                let program = EPGProgram(
                    id: id,
                    channelId: channelId,
                    title: title,
                    desc: currentProgramDesc,
                    category: currentProgramCategory,
                    start: start,
                    stop: stop
                )
                programs.append(program)
            }
            currentProgramChannel = nil
            currentProgramStart = nil
            currentProgramStop = nil
            currentProgramTitle = nil
            currentProgramDesc = nil
            currentProgramCategory = nil
        }
        currentElement = ""
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        completion?(channels, programs)
    }
} 