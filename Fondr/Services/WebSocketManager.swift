import Foundation

@Observable
final class WebSocketManager {
    static let shared = WebSocketManager()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var handlers: [String: [(Data) -> Void]] = [:]
    private(set) var isConnected = false
    private var pingTimer: Timer?

    private init() {}

    // MARK: - Connection

    func connect() {
        guard let token = TokenStore.shared.accessToken else { return }

        disconnect()

        let urlString = "wss://api.sashasaw-fondr-sandbox.eh1.incept5.dev/ws?token=\(token)"

        guard let url = URL(string: urlString) else { return }

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        receiveMessage()
        startPing()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session = nil
        isConnected = false
    }

    func reconnect() {
        disconnect()
        connect()
    }

    // MARK: - Event Handling

    func on<T: Decodable>(_ event: String, handler: @escaping (T) -> Void) {
        let wrappedHandler: (Data) -> Void = { data in
            if let decoded = try? JSONDecoder.apiDecoder.decode(T.self, from: data) {
                handler(decoded)
            }
        }
        handlers[event, default: []].append(wrappedHandler)
    }

    func removeHandlers(for events: [String]) {
        for event in events {
            handlers.removeValue(forKey: event)
        }
    }

    func removeAllHandlers() {
        handlers.removeAll()
    }

    // MARK: - Heartbeat

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.webSocket?.send(.string("ping")) { _ in }
        }
    }

    // MARK: - Receive

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                default:
                    break
                }
                self?.receiveMessage()
            case .failure:
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                // Auto-reconnect after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if TokenStore.shared.accessToken != nil {
                        self?.connect()
                    }
                }
            }
        }
    }

    private func handleMessage(_ raw: String) {
        // Server sends: {"event":"vault:created","data":{...}}
        guard raw != "pong" else { return }

        guard let jsonData = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let eventName = json["event"] as? String,
              let data = json["data"] else {
            return
        }

        guard let payloadData = try? JSONSerialization.data(withJSONObject: data) else {
            return
        }

        DispatchQueue.main.async {
            if let eventHandlers = self.handlers[eventName] {
                for handler in eventHandlers {
                    handler(payloadData)
                }
            }
        }
    }
}

// MARK: - JSON Decoder for API responses

extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: string) {
                return date
            }
            if let date = DateFormatter.yyyyMMdd.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }()
}
