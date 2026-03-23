import Foundation

@Observable
final class TMDBService {
    var searchResults: [TMDBResult] = []
    var isSearching = false

    var isConfigured: Bool {
        true // TMDB is now proxied through the backend — always available
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        await MainActor.run { isSearching = true }

        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: TMDBSearchResponse = try await APIClient.shared.get("/tmdb/search?query=\(encoded)")

            await MainActor.run {
                self.searchResults = response.results.map { movie in
                    TMDBResult(
                        id: movie.tmdbId,
                        title: movie.title,
                        posterPath: movie.posterUrl,
                        year: movie.year ?? "",
                        overview: movie.overview,
                        rating: movie.rating
                    )
                }
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    func clearResults() {
        searchResults = []
    }

    static func posterUrl(path: String) -> URL? {
        URL(string: path)
    }
}

// MARK: - Models

struct TMDBResult: Identifiable {
    let id: Int
    let title: String
    let posterPath: String?
    let year: String
    let overview: String?
    let rating: Double?
}

private struct TMDBSearchResponse: Decodable {
    let results: [TMDBMovie]
}

private struct TMDBMovie: Decodable {
    let tmdbId: Int
    let title: String
    let year: String?
    let overview: String?
    let posterUrl: String?
    let rating: Double?
}
