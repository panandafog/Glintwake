import AVFoundation
import SwiftUI

@MainActor
final class AudioController: ObservableObject {
    static let shared = AudioController()
    enum Effect: String, CaseIterable { case slide, crystal, undo, failure, win }

    @Published var effectsEnabled: Bool {
        didSet {
            defaults.set(effectsEnabled, forKey: "audio.effects")
            if !effectsEnabled { effects.values.forEach { $0.stop() } }
        }
    }
    @Published var ambienceEnabled: Bool {
        didSet {
            defaults.set(ambienceEnabled, forKey: "audio.ambience")
            updateAmbience()
        }
    }
    private var effects: [Effect: AVAudioPlayer] = [:]
    private var ambience: AVAudioPlayer?
    private var active = false
    private var interrupted = false
    private var observers: [NSObjectProtocol] = []
    #if DEBUG
    private let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ScreenshotSupport.isRequested
    #else
    private let testing = false
    #endif
    private let defaults: UserDefaults

    private init() {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ScreenshotSupport.isRequested
        if ScreenshotSupport.isRequested { defaults = UserDefaults(suiteName: "Glintwake.Screenshot." + UUID().uuidString)! }
        else { defaults = testing ? UserDefaults(suiteName: "Glintwake.AudioUITests")! : .standard }
        #else
        defaults = .standard
        #endif
        #if DEBUG
        if testing && !ScreenshotSupport.isRequested && !ProcessInfo.processInfo.arguments.contains("--keep-test-session") {
            defaults.removePersistentDomain(forName: "Glintwake.AudioUITests")
        }
        #endif
        effectsEnabled = defaults.object(forKey: "audio.effects") as? Bool ?? true
        ambienceEnabled = defaults.object(forKey: "audio.ambience") as? Bool ?? true
        #if DEBUG
        guard !testing else { return }
        #endif
        #if os(iOS)
        // Respect the silent switch and mix quietly with music from other apps.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor [weak self] in
                self?.interrupted = began
                if began { self?.effects.values.forEach { $0.stop() } }
                self?.updateAmbience()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let unplugged = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            if unplugged {
                Task { @MainActor [weak self] in self?.ambienceEnabled = false }
            }
        })
        #endif
        for effect in Effect.allCases {
            if let player = load(effect.rawValue) {
                player.volume = 0.55
                player.prepareToPlay()
                effects[effect] = player
            }
        }
        ambience = load("ambience")
        ambience?.numberOfLoops = -1
        ambience?.volume = 0.32
        ambience?.prepareToPlay()
    }

    func setActive(_ active: Bool) {
        self.active = active
        if !active { effects.values.forEach { $0.stop() } }
        updateAmbience()
    }

    func play(_ effect: Effect) {
        guard effectsEnabled, active, !interrupted, !testing, let player = effects[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    private func updateAmbience() {
        guard !testing else { return }
        if active && ambienceEnabled && !interrupted {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            if ambience?.isPlaying == false { ambience?.play() }
        } else {
            ambience?.pause()
        }
    }

    private func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        do { return try AVAudioPlayer(contentsOf: url) }
        catch { assertionFailure("Cannot load bundled audio \(name): \(error)"); return nil }
    }
}
