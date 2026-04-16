import Foundation
import os

nonisolated private let fileBookmarkLogger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "FileBookmark")

/// Helpers for creating and resolving security-scoped bookmarks.
///
/// Required because the app is sandboxed (`ENABLE_APP_SANDBOX = YES`).
/// File references must be persisted as bookmarks to survive app restarts.
nonisolated enum FileBookmark {

    /// Creates a security-scoped bookmark from a URL.
    static func create(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolves a security-scoped bookmark back to a URL.
    ///
    /// - Returns: The resolved URL and whether the bookmark is stale (needs recreation).
    static func resolve(_ bookmarkData: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            fileBookmarkLogger.warning("Bookmark is stale for \(url.lastPathComponent, privacy: .public). Consider re-selecting the file.")
        }
        return (url, isStale)
    }

    /// Resolves a bookmark and starts accessing the security-scoped resource.
    ///
    /// Caller MUST call `url.stopAccessingSecurityScopedResource()` when done.
    /// - Returns: The resolved URL, or nil if resolution or access fails.
    static func resolveAndAccess(_ bookmarkData: Data) -> URL? {
        guard let (url, isStale) = try? resolve(bookmarkData) else { return nil }

        // Attempt to recreate stale bookmark
        if isStale {
            fileBookmarkLogger.info("Attempting to refresh stale bookmark for \(url.lastPathComponent, privacy: .public)")
            // We can try to recreate but need access first
        }

        guard url.startAccessingSecurityScopedResource() else {
            fileBookmarkLogger.error("Failed to access security-scoped resource: \(url.lastPathComponent, privacy: .public)")
            return nil
        }
        return url
    }

    /// Executes a closure with security-scoped access to a bookmarked URL.
    ///
    /// Automatically starts and stops resource access.
    static func withAccess<T>(to bookmarkData: Data, perform action: (URL) throws -> T) throws -> T {
        let (url, _) = try resolve(bookmarkData)
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied(url)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try action(url)
    }

    nonisolated enum BookmarkError: Error, LocalizedError {
        case accessDenied(URL)

        var errorDescription: String? {
            switch self {
            case .accessDenied(let url):
                "Cannot access \(url.lastPathComponent). Please re-select the file."
            }
        }
    }
}
