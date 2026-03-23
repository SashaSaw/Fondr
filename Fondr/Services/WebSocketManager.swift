import Foundation

@Observable
final class WebSocketManager {
    static let shared = WebSocketManager()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var handlers: [String: [(Data) -> Void]] = [:]
    private(set) var isConnected = false

    private init() {}

    // MARK: - Connection

    func connect() {
        guard let token = TokenStore.shared.accessToken else { return }

        disconnect()

        #if DEBUG
        let urlString = "ws://localhost:3000/socket.io/?EIO=4&transport=websocket&token=\(token)"
        #else
        let urlString = "wss://api.fondr.app/socket.io/?EIO=4&transport=websocket&token=\(token)"
        #endif

        guard let url = URL(string: urlString) else { return }

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        // Send Socket.IO handshake
        send(raw: "40")

        isConnected = true
        receiveMessage()
    }

    func disconnect() {
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

    func removeAllHandlers() {
        handlers.removeAll()
    }

    // MARK: - Send

    private func send(raw text: String) {
        webSocket?.send(.string(text)) { _ in }
    }

    // MARK: - Receive

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleSocketIOMessage(text)
                default:
                    break
                }
                // Continue listening
                self?.receiveMessage()
            case .failure:
                self?.isConnected = false
                // Auto-reconnect after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if TokenStore.shared.accessToken != nil {
                        self?.connect()
                    }
                }
            }
        }
    }

    private func handleSocketIOMessage(_ raw: String) {
        // Socket.IO protocol: "42" prefix means event message
        // Format: 42["eventName", {data}]
        guard raw.hasPrefix("42") else {
            // Handle ping "2" -> respond with pong "3"
            if raw == "2" {
                send(raw: "3")
            }
            return
        }

        let jsonString = String(raw.dropFirst(2))
        guard let jsonData = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
              array.count >= 2,
              let eventName = array[0] as? String else {
            return
        }

        // Serialize the event payload back to Data for decoding
        guard let payloadData = try? JSONSerialization.data(withJSONObject: array[1]) else {
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
