import Foundation
import AVFoundation
import CoreMotion
import CoreLocation
import ImageIO

final class NoiseMeter: ObservableObject {
    @Published var db: Double = 0
    @Published var peak: Double = 0
    @Published var average: Double = 0
    @Published var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var samples: [Double] = []

    func start() {
        if let s = Showcase.scene { if s == "noise" { db = 42.6; peak = 51.3; average = 40.8 }; return }
        AVAudioApplication.requestRecordPermission { ok in
            DispatchQueue.main.async { ok ? self.begin() : (self.denied = true) }
        }
    }

    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement)
        try? session.setActive(true)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]
        guard let r = try? AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings) else { return }
        r.isMeteringEnabled = true
        r.record()
        recorder = r
        samples = []; peak = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let r = recorder else { return }
        r.updateMeters()
        let v = min(120, max(0, Double(r.averagePower(forChannel: 0)) + 100))
        db = db * 0.7 + v * 0.3
        peak = max(peak, db)
        samples.append(db); if samples.count > 300 { samples.removeFirst() }
        average = samples.reduce(0, +) / Double(samples.count)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func describe(_ db: Double) -> String {
        switch db {
        case ..<30: "とても静か（深夜の郊外くらい）"
        case ..<40: "静か（図書館くらい）"
        case ..<50: "ふつう（静かな住宅地の昼）"
        case ..<60: "やや気になる（普通の会話くらい）"
        case ..<70: "うるさい（にぎやかな道路沿い）"
        default: "かなりうるさい（電車の車内くらい）"
        }
    }
}

final class TiltMeter: ObservableObject {
    @Published var x: Double = 0
    @Published var y: Double = 0
    @Published var available = true
    private let motion = CMMotionManager()

    var angle: Double { max(abs(x), abs(y)) }
    var mmPerMeter: Double { tan(angle * .pi / 180) * 1000 }

    func start() {
        if Showcase.scene != nil { x = 0.21; y = -0.38; return }
        guard motion.isDeviceMotionAvailable else { available = false; return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            let nx = asin(max(-1, min(1, g.x))) * 180 / .pi
            let ny = asin(max(-1, min(1, g.y))) * 180 / .pi
            self.x = self.x * 0.8 + nx * 0.2
            self.y = self.y * 0.8 + ny * 0.2
        }
    }
    func stop() { motion.stopDeviceMotionUpdates() }

    static func describe(_ angle: Double) -> String {
        switch angle {
        case ..<0.35: "ほぼ水平（気にならない程度）"
        case ..<0.6: "わずかに傾き（ビー玉が転がることも）"
        case ..<1.0: "傾きを感じる人もいる"
        default: "傾きが大きめ。管理会社に確認を"
        }
    }
}

final class Compass: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var available = true
    private let manager = CLLocationManager()

    func start() {
        if Showcase.scene != nil { heading = 172; return }
        guard CLLocationManager.headingAvailable() else { available = false; return }
        manager.delegate = self
        manager.headingFilter = 1
        manager.startUpdatingHeading()
    }
    func stop() { manager.stopUpdatingHeading() }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading
    }
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }

    static func direction(_ deg: Double) -> String {
        let names = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
        return names[Int((deg + 22.5).truncatingRemainder(dividingBy: 360) / 45) % 8]
    }
}

final class LightMeter: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var lux: Double = 0
    @Published var denied = false
    @Published var available = true
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "light")
    private var last = Date.distantPast

    func start() {
        if Showcase.scene != nil { lux = 412; return }
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async { ok ? self.configure() : (self.denied = true) }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { available = false; return }
        session.beginConfiguration()
        session.sessionPreset = .low
        if session.inputs.isEmpty, session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        if session.outputs.isEmpty, session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        queue.async { self.session.startRunning() }
    }

    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(last) > 0.3 else { return }
        last = Date()
        guard let dict = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
              let exif = dict[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let bv = exif[kCGImagePropertyExifBrightnessValue as String] as? Double else { return }
        let value = max(0, 2.5 * pow(2, bv))
        DispatchQueue.main.async { self.lux = self.lux == 0 ? value : self.lux * 0.6 + value * 0.4 }
    }

    static func describe(_ lux: Double) -> String {
        switch lux {
        case ..<50: "暗い（照明なしでは過ごしにくい）"
        case ..<200: "やや暗い（曇りの日の室内くらい）"
        case ..<750: "ふつう（照明をつけた居間くらい）"
        case ..<2000: "明るい（窓ぎわの日中）"
        default: "とても明るい（日がよく入る）"
        }
    }
}
