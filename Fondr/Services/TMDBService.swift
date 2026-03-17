import Foundation

@Observable
final class TMDBService {
    var searchResults: [TMDBResult] = []
    var isSearching = false

    var isConfigured: Bool {
        !Constants.TMDB.apiKey.isEmpty
    }

    func search(query: String) async {
        guard isConfigured, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        await MainActor.run { isSearching = true }

        do {
            var components = URLComponents(string: "\(Constants.TMDB.baseUrl)/search/movie")!
            components.queryItems = [
                URLQueryItem(name: "api_key", value: Constants.TMDB.apiKey),
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: "1")
            ]

            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(TMDBResponse.self, from: data)

            await MainActor.run {
                self.searchResults = response.results.prefix(10).map { movie in
                    TMDBResult(
                        id: movie.id,
                        title: movie.title,
                        posterPath: movie.posterPath,
                        year: String(movie.releaseDate?.prefix(4) ?? ""),
                        overview: movie.overview,
                        rating: movie.voteAverage
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
        URL(string: "\(Constants.TMDB.imageBaseUrl)\(path)")
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

private struct TMDBResponse: Decodable {
    let results: [TMDBMovie]
}

private struct TMDBMovie: Decodable {
    let id: Int
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let overview: String?
    let voteAverage: Double?
}
