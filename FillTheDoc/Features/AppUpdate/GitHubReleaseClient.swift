import Foundation

nonisolated enum GitHubReleaseClientError: LocalizedError {
    case invalidResponseStatus(Int)
    case invalidHTTPResponse
    
    var errorDescription: String? {
        switch self {
            case .invalidResponseStatus(let code):
                return "GitHub вернул ошибку со статусом \(code)."
            case .invalidHTTPResponse:
                return "Некорректный ответ сервера."
        }
    }
}

actor GitHubReleaseClient {
    private let owner: String
    private let repo: String
    private let session: URLSession
    
    init(owner: String, repo: String, session: URLSession = .shared) {
        self.owner = owner
        self.repo = repo
        self.session = session
    }
    
    func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("FillTheDoc", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw GitHubReleaseClientError.invalidHTTPResponse
        }
        
        guard 200..<300 ~= http.statusCode else {
            throw GitHubReleaseClientError.invalidResponseStatus(http.statusCode)
        }
        
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}
