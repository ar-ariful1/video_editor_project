// flutter_app/ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import AVFoundation
import Photos

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    private let ENGINE_CHANNEL = "com.yourcompany.videoeditorpro/engine"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: ENGINE_CHANNEL, binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {

            case "getMediaInfo":
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String else {
                    result(FlutterError(code: "INVALID_ARG", message: "path required", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let info = self?.getMediaInfo(path: path) ?? [:]
                    DispatchQueue.main.async { result(info) }
                }

            case "getThumbnail":
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String else {
                    result(FlutterError(code: "INVALID_ARG", message: "path required", details: nil))
                    return
                }
                let time = (args["time"] as? Double) ?? 0.0
                DispatchQueue.global(qos: .userInitiated).async {
                    let thumbPath = self?.generateThumbnail(path: path, time: time)
                    DispatchQueue.main.async { result(thumbPath) }
                }

            case "saveToGallery":
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String else {
                    result(FlutterError(code: "INVALID_ARG", message: "path required", details: nil))
                    return
                }
                self?.saveVideoToGallery(path: path) { success in
                    result(success)
                }

            case "getDeviceInfo":
                result([
                    "model": UIDevice.current.model,
                    "systemVersion": UIDevice.current.systemVersion,
                    "isSimulator": ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil,
                    "hasHardwareEncoder": true,
                ])

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ── Media Info ────────────────────────────────────────────────────────────

    private func getMediaInfo(path: String) -> [String: Any] {
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)

        var width = 0, height = 0
        var fps = 30.0
        var hasAudio = false

        for track in asset.tracks {
            if track.mediaType == .video {
                let size = track.naturalSize.applying(track.preferredTransform)
                width  = Int(abs(size.width))
                height = Int(abs(size.height))
                fps    = Double(track.nominalFrameRate)
            }
            if track.mediaType == .audio { hasAudio = true }
        }

        return [
            "duration": duration, "width": width, "height": height,
            "fps": fps, "hasAudio": hasAudio, "bitrate": asset.tracks.first?.estimatedDataRate ?? 0,
        ]
    }

    // ── Thumbnail ─────────────────────────────────────────────────────────────

    private func generateThumbnail(path: String, time: Double) -> String? {
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) else { return nil }

        let uiImage = UIImage(cgImage: cgImage)
        let outPath = NSTemporaryDirectory() + "thumb_\(Date().timeIntervalSince1970).jpg"
        if let data = uiImage.jpegData(compressionQuality: 0.85) {
            try? data.write(to: URL(fileURLWithPath: outPath))
            return outPath
        }
        return nil
    }

    // ── Save to Photo Library ─────────────────────────────────────────────────

    private func saveVideoToGallery(path: String, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { completion(false); return }

            PHPhotoLibrary.shared().performChanges({
                let url = URL(fileURLWithPath: path)
                let options = PHAssetResourceCreationOptions()
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: url, options: options)
            }) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }
}
