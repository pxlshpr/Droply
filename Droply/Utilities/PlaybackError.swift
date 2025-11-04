//
//  PlaybackError.swift
//  Droply
//
//  Created by Ahmed Khalaf on 11/4/25.
//

import Foundation

/// User-facing errors for playback operations
enum PlaybackError: LocalizedError {
    case playbackFailed
    case pauseFailed
    case skipNextFailed
    case skipPreviousFailed
    case seekFailed
    case databaseSaveFailed
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Failed to play song"
        case .pauseFailed:
            return "Failed to pause playback"
        case .skipNextFailed:
            return "Can't skip to next song"
        case .skipPreviousFailed:
            return "Can't skip to previous song"
        case .seekFailed:
            return "Failed to seek in song"
        case .databaseSaveFailed:
            return "Failed to save marker"
        case .unknownError(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .playbackFailed:
            return "Check your Apple Music subscription and network connection"
        case .pauseFailed:
            return "Try again or restart the app"
        case .skipNextFailed:
            return "You may have reached the end of your queue"
        case .skipPreviousFailed:
            return "You may be at the start of your queue"
        case .seekFailed:
            return "Try again or restart playback"
        case .databaseSaveFailed:
            return "Your marker may not be saved. Try adding it again"
        case .unknownError:
            return "Try restarting the app"
        }
    }
}
