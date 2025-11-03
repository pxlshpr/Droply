//
//  AppleMusicQueueManager.swift
//  Droply
//
//  Simplified queue management from MusicStack framework
//

import Foundation
import MediaPlayer
import OSLog

@MainActor
class AppleMusicQueueManager {
    static let shared = AppleMusicQueueManager()

    private let systemPlayer = MPMusicPlayerController.systemMusicPlayer
    private let logger = Logger(subsystem: "com.droply.app", category: "QueueManager")

    // Debouncing state for queue management
    private var pendingQueueTask: Task<Void, Never>?
    private let queueDebounceDelay: UInt64 = 1_500_000_000 // 1.5 seconds in nanoseconds

    private init() {
        systemPlayer.beginGeneratingPlaybackNotifications()
    }

    // MARK: - Public Methods

    /// Plays a single item immediately
    func play(_ item: ItemToPlay) async throws {
        logger.info("Playing single item: \(item.title) by \(item.artist)")
        try await setQueue(with: item)
        systemPlayer.play()
    }

    /// Plays multiple items, starting with the first
    func play(_ items: [ItemToPlay]) async throws {
        guard !items.isEmpty else {
            logger.warning("Attempted to play empty list")
            throw QueueError.emptyQueue
        }

        logger.info("Playing \(items.count) items, starting with: \(items[0].title)")

        // Set queue with first item
        guard let firstValidIndex = await setQueueWithFirstValidItem(from: items) else {
            logger.error("No valid items found to play")
            throw QueueError.invalidItem
        }

        logger.info("Successfully set queue, now starting playback")

        // Start playing
        systemPlayer.shuffleMode = .off
        systemPlayer.repeatMode = .all
        systemPlayer.play()

        logger.info("Called systemPlayer.play()")

        // Append remaining items
        let remaining = Array(items.dropFirst(firstValidIndex + 1))
        await appendItems(remaining)
    }

    /// Plays multiple items with debouncing - first song plays immediately,
    /// rest of queue is added after a delay. If called again before delay completes,
    /// cancels the previous queue and starts over.
    func playWithDebounce(_ items: [ItemToPlay]) async throws {
        guard !items.isEmpty else {
            logger.warning("Attempted to play empty list")
            throw QueueError.emptyQueue
        }

        // Cancel any pending queue task
        if let existingTask = pendingQueueTask {
            logger.info("Cancelling previous pending queue task")
            existingTask.cancel()
            pendingQueueTask = nil
        }

        logger.info("Playing with debounce: \(items.count) items, starting with: \(items[0].title)")

        // Set queue with ONLY the first item
        guard let firstValidIndex = await setQueueWithFirstValidItem(from: [items[0]]) else {
            logger.error("No valid items found to play")
            throw QueueError.invalidItem
        }

        logger.info("Successfully set queue with first item, now starting playback")

        // Start playing immediately
        systemPlayer.shuffleMode = .off
        systemPlayer.repeatMode = .all
        systemPlayer.play()

        logger.info("Called systemPlayer.play() for first item")

        // Only queue remaining items if there are more than 1 item total
        guard items.count > 1 else {
            logger.info("Only one item to play, no need to queue more")
            return
        }

        // Schedule task to append remaining items after delay
        let remaining = Array(items.dropFirst(1))
        pendingQueueTask = Task { @MainActor in
            do {
                logger.info("Waiting \(Double(self.queueDebounceDelay) / 1_000_000_000)s before queueing remaining \(remaining.count) items")
                try await Task.sleep(nanoseconds: self.queueDebounceDelay)

                // Check if task was cancelled
                if Task.isCancelled {
                    self.logger.info("Queue task was cancelled before appending items")
                    return
                }

                self.logger.info("Debounce delay completed, now appending \(remaining.count) items")
                await self.appendItems(remaining)
                self.logger.info("Successfully queued remaining items")

                // Clear the task reference
                self.pendingQueueTask = nil
            } catch {
                // Task was cancelled or sleep was interrupted
                self.logger.info("Queue task interrupted: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Queue Management

    /// Sets the queue with a single item
    private func setQueue(with item: ItemToPlay) async throws {
        logger.debug("Setting queue with: \(item.title)")

        if item.isAppleStoreItem, let storeID = item.validAppleStoreID {
            // Apple Music catalog item
            logger.info("Setting queue with store ID: \(storeID)")
            systemPlayer.setQueue(with: [storeID])

            do {
                try await systemPlayer.prepareToPlay()
                logger.info("Successfully prepared to play: \(item.title)")
            } catch {
                logger.error("Failed to prepare playback for \(item.title): \(error.localizedDescription)")
                throw error
            }
        } else if item.isAppleLibraryItem {
            // Library item - need to look it up
            logger.debug("Looking up library item")
            if let mediaItem = await findLibraryItem(for: item) {
                let descriptor = MPMusicPlayerMediaItemQueueDescriptor(
                    itemCollection: .init(items: [mediaItem])
                )
                systemPlayer.setQueue(with: descriptor)
                try await systemPlayer.prepareToPlay()
            } else {
                logger.error("Could not find library item for: \(item.title)")
                throw QueueError.libraryItemNotFound
            }
        } else {
            logger.error("Item has no valid Apple Music identifier")
            throw QueueError.invalidItem
        }
    }

    /// Finds the first valid item and sets it as the queue
    private func setQueueWithFirstValidItem(from items: [ItemToPlay]) async -> Int? {
        for (index, item) in items.enumerated() {
            do {
                try await setQueue(with: item)
                logger.debug("Set queue with item at index \(index): \(item.title)")
                return index
            } catch {
                logger.warning("Failed to set queue with item at index \(index): \(error.localizedDescription)")
                continue
            }
        }
        return nil
    }

    /// Appends items to the existing queue
    private func appendItems(_ items: [ItemToPlay]) async {
        logger.debug("Appending \(items.count) items to queue")

        // Group items by type (store vs library)
        let (storeItems, libraryItems) = items.reduce(into: ([ItemToPlay](), [ItemToPlay]())) { result, item in
            if item.isAppleStoreItem {
                result.0.append(item)
            } else if item.isAppleLibraryItem {
                result.1.append(item)
            }
        }

        // Append store items as one batch
        if !storeItems.isEmpty {
            let storeIDs = storeItems.compactMap { $0.validAppleStoreID }
            if !storeIDs.isEmpty {
                let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: storeIDs)
                systemPlayer.append(descriptor)
                logger.debug("Appended \(storeIDs.count) store items")
            }
        }

        // Append library items individually
        for item in libraryItems {
            if let mediaItem = await findLibraryItem(for: item) {
                let descriptor = MPMusicPlayerMediaItemQueueDescriptor(
                    itemCollection: .init(items: [mediaItem])
                )
                systemPlayer.append(descriptor)
                logger.debug("Appended library item: \(item.title)")
            }
        }
    }

    /// Finds a library item by persistent ID or metadata
    private func findLibraryItem(for item: ItemToPlay) async -> MPMediaItem? {
        logger.debug("Searching for library item: \(item.title) by \(item.artist)")

        // Try by persistent ID first
        if let persistentID = item.validApplePersistentID,
           let id = UInt64(persistentID) {
            let query = MPMediaQuery.songs()
            let predicate = MPMediaPropertyPredicate(
                value: id,
                forProperty: MPMediaItemPropertyPersistentID
            )
            query.addFilterPredicate(predicate)

            if let mediaItem = query.items?.first {
                logger.debug("Found library item by persistent ID")
                return mediaItem
            }
        }

        // Fallback: search by title and artist
        let titlePredicate = MPMediaPropertyPredicate(
            value: item.title,
            forProperty: MPMediaItemPropertyTitle,
            comparisonType: .equalTo
        )
        let artistPredicate = MPMediaPropertyPredicate(
            value: item.artist,
            forProperty: MPMediaItemPropertyArtist,
            comparisonType: .equalTo
        )

        let query = MPMediaQuery.songs()
        query.addFilterPredicate(titlePredicate)
        query.addFilterPredicate(artistPredicate)

        if let items = query.items, !items.isEmpty {
            // If multiple matches, try to match by duration
            if items.count > 1, let duration = item.durationInSeconds {
                let matches = items.filter { abs($0.playbackDuration - duration) < 1.0 }
                if let match = matches.first {
                    logger.debug("Found library item by title/artist/duration")
                    return match
                }
            }

            // Return first match
            logger.debug("Found library item by title/artist")
            return items.first
        }

        logger.warning("Library item not found")
        return nil
    }
}

// MARK: - Errors

enum QueueError: Error, LocalizedError {
    case invalidItem
    case libraryItemNotFound
    case emptyQueue

    var errorDescription: String? {
        switch self {
        case .invalidItem:
            return "Item has no valid Apple Music identifier"
        case .libraryItemNotFound:
            return "Could not find item in library"
        case .emptyQueue:
            return "Queue is empty"
        }
    }
}
