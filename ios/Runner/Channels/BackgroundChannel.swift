import Flutter
import AVFoundation
import CoreLocation
import os.log

/// Platform channel for background service management on iOS.
///
/// Uses Background Audio (AVAudioSession) + Background Location to keep
/// the app alive in background. Camera is NOT available in background on iOS.
class BackgroundChannel: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
    static let channelName = "com.kita/background"
    static let eventChannelName = "com.kita/service_state"
    private static let log = OSLog(subsystem: "com.kita", category: "BackgroundService")

    private let channel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var locationManager: CLLocationManager?
    private var isServiceRunning = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: messenger)

        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "DISPOSED", message: "Channel disposed", details: nil))
                return
            }
            self.handleMethodCall(call, result: result)
        }

        eventChannel.setStreamHandler(self)
    }

    // MARK: - Method Channel Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startService":
            startService(result: result)
        case "stopService":
            stopService(result: result)
        case "isRunning":
            result(isServiceRunning)
        case "isBatteryOptimizationIgnored":
            // iOS does not have battery optimization exemption
            result(true)
        case "requestBatteryOptimizationExemption":
            // No-op on iOS
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Service Lifecycle

    private func startService(result: @escaping FlutterResult) {
        configureAudioSession()
        configureLocationManager()
        isServiceRunning = true
        sendState("running")
        result(true)
    }

    private func stopService(result: @escaping FlutterResult) {
        deactivateAudioSession()
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        isServiceRunning = false
        sendState("stopped")
        result(true)
    }

    // MARK: - Audio Session (Background keepalive)

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps the app active in background
            // .mixWithOthers does not interrupt user's music
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Log without PII
            os_log("AVAudioSession configuration failed", log: Self.log, type: .error)
        }
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            os_log("AVAudioSession deactivation failed", log: Self.log, type: .error)
        }
    }

    // MARK: - Location Manager (Background updates)

    private func configureLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.distanceFilter = 10 // meters — reduce battery drain
        locationManager?.pausesLocationUpdatesAutomatically = false

        // Request always authorization if not already granted
        let status = locationManager?.authorizationStatus ?? .notDetermined
        if status == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            locationManager?.requestAlwaysAuthorization()
        }

        // Only enable background location and start updates with Always authorization
        if status == .authorizedAlways {
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates keep the app alive in background.
        // Actual location processing is handled by LocationService (E3).
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log without PII (no coordinates)
        os_log("Location update failed", log: Self.log, type: .error)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
        } else if status == .authorizedWhenInUse {
            // Upgrade to Always for background operation
            manager.requestAlwaysAuthorization()
        }
    }

    // MARK: - Event Channel (State Stream)

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func sendState(_ state: String) {
        eventSink?(["state": state])
    }
}
