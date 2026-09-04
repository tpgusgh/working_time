import AppKit

final class NowPlayingController {
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, @convention(block) @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFunction = @convention(c) (Int, AnyObject?) -> Bool
    private typealias RegisterFunction = @convention(c) (DispatchQueue) -> Void

    private enum Command: Int {
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    struct NowPlayingInfo {
        let title: String?
        let artist: String?
        let artwork: NSImage?
        let isPlaying: Bool
        let elapsedTime: Double
        let duration: Double
    }

    private let getNowPlayingInfo: GetInfoFunction?
    private let sendCommand: SendCommandFunction?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle, let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: GetInfoFunction.self)
        } else {
            getNowPlayingInfo = nil
        }
        if let handle, let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: SendCommandFunction.self)
        } else {
            sendCommand = nil
        }
        // Browser tabs (YouTube Music, etc.) don't populate GetNowPlayingInfo
        // at all unless the process has registered as a now-playing-info
        // listener first — native apps (Music.app) work either way, but
        // registering is required for the browser case. Verified empirically:
        // without this call, a playing YouTube Music tab returns an empty
        // dictionary from GetNowPlayingInfo.
        if let handle, let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let register = unsafeBitCast(sym, to: RegisterFunction.self)
            register(DispatchQueue.global())
        }
    }

    // Blocks the calling thread briefly (never the main queue's own dispatch
    // target) for a synchronous read — the caller here is menu construction,
    // which is simplest done as one linear pass. MediaRemote's callback runs
    // on DispatchQueue.global(), so waiting on the calling thread never
    // deadlocks even when called from the main thread.
    func fetchNowPlaying(timeout: TimeInterval = 0.5) -> NowPlayingInfo? {
        guard let getNowPlayingInfo else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var result: NowPlayingInfo?
        getNowPlayingInfo(DispatchQueue.global()) { info in
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            var artwork: NSImage?
            if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artwork = NSImage(data: data)
            }
            result = NowPlayingInfo(title: title, artist: artist, artwork: artwork, isPlaying: rate > 0, elapsedTime: elapsed, duration: duration)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    func togglePlayPause() {
        _ = sendCommand?(Command.togglePlayPause.rawValue, nil)
    }

    func nextTrack() {
        _ = sendCommand?(Command.nextTrack.rawValue, nil)
    }

    func previousTrack() {
        _ = sendCommand?(Command.previousTrack.rawValue, nil)
    }
}
