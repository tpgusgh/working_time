import AppKit

final class NowPlayingPopoverViewController: NSViewController {
    private let artworkView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let progressBar = NSProgressIndicator()
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    private let focusToggleButton = NSButton()

    private let nowPlaying: NowPlayingController
    var onFocusToggle: (() -> Void)?

    init(nowPlaying: NowPlayingController) {
        self.nowPlaying = nowPlaying
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 196))
        buildUI()
    }

    private func buildUI() {
        artworkView.frame = NSRect(x: 16, y: 126, width: 56, height: 56)
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(artworkView)

        titleLabel.frame = NSRect(x: 84, y: 156, width: 160, height: 18)
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(titleLabel)

        artistLabel.frame = NSRect(x: 84, y: 136, width: 160, height: 16)
        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(artistLabel)

        progressBar.frame = NSRect(x: 16, y: 114, width: 228, height: 8)
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        view.addSubview(progressBar)

        previousButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "이전 곡")
        previousButton.isBordered = false
        previousButton.frame = NSRect(x: 70, y: 78, width: 32, height: 28)
        previousButton.target = self
        previousButton.action = #selector(previousTapped)
        view.addSubview(previousButton)

        playPauseButton.isBordered = false
        playPauseButton.frame = NSRect(x: 114, y: 78, width: 32, height: 28)
        playPauseButton.target = self
        playPauseButton.action = #selector(playPauseTapped)
        view.addSubview(playPauseButton)

        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "다음 곡")
        nextButton.isBordered = false
        nextButton.frame = NSRect(x: 158, y: 78, width: 32, height: 28)
        nextButton.target = self
        nextButton.action = #selector(nextTapped)
        view.addSubview(nextButton)

        let separator = NSBox(frame: NSRect(x: 16, y: 62, width: 228, height: 1))
        separator.boxType = .separator
        view.addSubview(separator)

        focusToggleButton.frame = NSRect(x: 16, y: 20, width: 228, height: 32)
        focusToggleButton.bezelStyle = .rounded
        focusToggleButton.target = self
        focusToggleButton.action = #selector(focusToggleTapped)
        view.addSubview(focusToggleButton)
    }

    func refresh(isFocusOn: Bool) {
        focusToggleButton.title = isFocusOn ? "포커스 끄기" : "포커스 켜기"

        guard let info = nowPlaying.fetchNowPlaying(timeout: 1.5), info.title != nil || info.artist != nil else {
            titleLabel.stringValue = "재생 중인 곡 없음"
            artistLabel.stringValue = ""
            artworkView.image = nil
            progressBar.doubleValue = 0
            playPauseButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "재생")
            return
        }

        titleLabel.stringValue = info.title ?? ""
        artistLabel.stringValue = info.artist ?? ""
        artworkView.image = info.artwork
        progressBar.doubleValue = info.duration > 0 ? info.elapsedTime / info.duration : 0
        playPauseButton.image = NSImage(
            systemSymbolName: info.isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: "재생/일시정지"
        )
    }

    @objc private func previousTapped() {
        nowPlaying.previousTrack()
        refresh(isFocusOn: focusToggleButton.title == "포커스 끄기")
    }

    @objc private func playPauseTapped() {
        nowPlaying.togglePlayPause()
        refresh(isFocusOn: focusToggleButton.title == "포커스 끄기")
    }

    @objc private func nextTapped() {
        nowPlaying.nextTrack()
        refresh(isFocusOn: focusToggleButton.title == "포커스 끄기")
    }

    @objc private func focusToggleTapped() {
        onFocusToggle?()
    }
}
