import Foundation

/// Client for the Rust/Axum backend. Set `SUDOKU_API_URL` in the scheme's
/// environment or edit `baseURL` to point at your Heroku app.
struct APIClient {
    let baseURL: URL

    init() {
        let env = ProcessInfo.processInfo.environment["SUDOKU_API_URL"]
        baseURL = URL(string: env ?? "https://YOUR-APP.herokuapp.com")!
    }

    private var deviceID: String {
        let key = "sudoku.deviceId.v1"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    func fetchPuzzle(size: Int, difficulty: String) async -> Puzzle? {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/puzzle"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "difficulty", value: difficulty),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(Puzzle.self, from: data)
    }

    /// Best-effort save into the backend's SQLite; local UserDefaults is the
    /// source of truth (the Heroku dyno filesystem is ephemeral).
    func syncGame(_ game: GameState, isNewGame: Bool) async {
        struct Body: Encodable {
            let id: Int64?
            let device_id: String
            let size: Int
            let difficulty: String
            let state: GameState
        }
        let idKey = "sudoku.serverGameId.v1"
        let storedID = isNewGame ? nil : UserDefaults.standard.object(forKey: idKey) as? Int64

        var request = URLRequest(url: baseURL.appendingPathComponent("api/games"))
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Body(id: storedID, device_id: deviceID, size: game.puzzle.size,
                        difficulty: game.puzzle.difficulty.rawValue, state: game)
        guard let encoded = try? JSONEncoder().encode(body) else { return }
        request.httpBody = encoded

        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404, storedID != nil {
            // Dyno restarted and wiped SQLite: re-create the row.
            UserDefaults.standard.removeObject(forKey: idKey)
            await syncGame(game, isNewGame: true)
            return
        }
        guard status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int64 ?? (json["id"] as? Int).map(Int64.init)
        else { return }
        UserDefaults.standard.set(id, forKey: idKey)
    }
}
