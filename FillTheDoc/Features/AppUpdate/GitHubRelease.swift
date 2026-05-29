import Foundation

nonisolated struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let body: String?
    let assets: [Asset]
    
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL
        
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case assets
    }
}
