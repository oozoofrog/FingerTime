//
//  FacePhotos.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import SwiftUI
import UIKit
import Vision

enum PhotoSlot: String, CaseIterable, Identifiable {
    case center
    case hourHandTip
    case minuteHandTip
    case secondHandTip

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .center:
            "중앙"
        case .hourHandTip:
            "시침"
        case .minuteHandTip:
            "분침"
        case .secondHandTip:
            "초침"
        }
    }

    var placeholder: String {
        switch self {
        case .center:
            "🧒"
        case .hourHandTip:
            "👨"
        case .minuteHandTip:
            "👩"
        case .secondHandTip:
            "⭐️"
        }
    }

    var fileName: String {
        "\(rawValue).jpg"
    }
}

@MainActor @Observable
final class FacePhotoStore {
    private(set) var images: [PhotoSlot: UIImage] = [:]

    private let directory: URL

    init(fileManager: FileManager = .default) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        directory = documents?.appendingPathComponent("FacePhotos", isDirectory: true) ?? fileManager.temporaryDirectory
        PhotoFlowDebug.info("FacePhotoStore init directory=\(self.directory.path)")
        do {
            try fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
            PhotoFlowDebug.info("FacePhotoStore directory ready")
        } catch {
            PhotoFlowDebug.error("FacePhotoStore directory create failed error=\(error.localizedDescription)")
        }
        loadSavedImages()
    }

    func image(for slot: PhotoSlot) -> UIImage? {
        PhotoFlowDebug.debug("FacePhotoStore image lookup slot=\(slot.rawValue) hit=\(self.images[slot] != nil)")
        return images[slot]
    }

    func save(_ image: UIImage, for slot: PhotoSlot) {
        PhotoFlowDebug.info("FacePhotoStore save requested slot=\(slot.rawValue) sourceSize=\(String(describing: image.size))")
        let croppedImage: UIImage
        if let faceCenter = detectFaceCenter(in: image) {
            PhotoFlowDebug.info("FacePhotoStore face detected at (\(faceCenter.x), \(faceCenter.y)) slot=\(slot.rawValue)")
            croppedImage = faceCroppedSquare(image, faceCenter: faceCenter)
        } else {
            croppedImage = centerCroppedSquare(image)
        }
        guard let data = croppedImage.jpegData(compressionQuality: 0.82) else {
            PhotoFlowDebug.error("FacePhotoStore jpeg encoding failed slot=\(slot.rawValue)")
            return
        }
        let destination = fileURL(for: slot)
        do {
            try data.write(to: destination, options: [.atomic])
            PhotoFlowDebug.info("FacePhotoStore save succeeded slot=\(slot.rawValue) bytes=\(data.count) path=\(destination.path)")
        } catch {
            PhotoFlowDebug.error("FacePhotoStore save failed slot=\(slot.rawValue) error=\(error.localizedDescription)")
        }
        images[slot] = croppedImage
    }

    private func loadSavedImages() {
        for slot in PhotoSlot.allCases {
            let path = fileURL(for: slot).path
            if let image = UIImage(contentsOfFile: path) {
                images[slot] = image
                PhotoFlowDebug.info("FacePhotoStore loaded saved image slot=\(slot.rawValue) path=\(path)")
            } else {
                PhotoFlowDebug.info("FacePhotoStore no saved image slot=\(slot.rawValue) path=\(path)")
            }
        }
    }

    private func fileURL(for slot: PhotoSlot) -> URL {
        directory.appendingPathComponent(slot.fileName)
    }

    private func detectFaceCenter(in image: UIImage) -> CGPoint? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            PhotoFlowDebug.error("FacePhotoStore face detection failed: \(error.localizedDescription)")
            return nil
        }
        guard let face = request.results?
            .max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        else { return nil }

        let box = face.boundingBox
        return CGPoint(
            x: box.midX * image.size.width,
            y: (1 - box.midY) * image.size.height
        )
    }

    private func faceCroppedSquare(_ image: UIImage, faceCenter: CGPoint, side: CGFloat = 512) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }

        let scale = max(side / image.size.width, side / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawX = min(0, max(side - scaledSize.width, side / 2 - faceCenter.x * scale))
        let drawY = min(0, max(side - scaledSize.height, side / 2 - faceCenter.y * scale))
        let drawRect = CGRect(x: drawX, y: drawY, width: scaledSize.width, height: scaledSize.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: drawRect)
        }
    }

    private func centerCroppedSquare(_ image: UIImage, side: CGFloat = 512) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else {
            PhotoFlowDebug.error("FacePhotoStore crop skipped invalid size=\(String(describing: image.size))")
            return image
        }

        let scale = max(side / image.size.width, side / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawRect = CGRect(
            x: (side - scaledSize.width) / 2,
            y: (side - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: drawRect)
        }
    }
}

struct FacePhotoButton: View {
    let slot: PhotoSlot
    let image: UIImage?
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            PhotoFlowDebug.info("FacePhotoButton tapped slot=\(slot.rawValue) hasImage=\(image != nil) size=\(size)")
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.9), lineWidth: max(3, size * 0.07))
                    )
                    .shadow(color: .cyan.opacity(0.65), radius: 14)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 8)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(slot.placeholder)
                        .font(.system(size: size * 0.48))
                }

                Circle()
                    .strokeBorder(.cyan.opacity(0.55), lineWidth: 2)
            }
            .frame(width: size, height: size)
            .accessibilityLabel("\(slot.label) 얼굴 사진 선택")
        }
        .buttonStyle(.plain)
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        PhotoFlowDebug.info("CameraImagePicker makeUIViewController")
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        PhotoFlowDebug.debug("CameraImagePicker updateUIViewController")
    }

    func makeCoordinator() -> Coordinator {
        PhotoFlowDebug.info("CameraImagePicker makeCoordinator")
        return Coordinator(parent: self)
    }

    @MainActor final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            PhotoFlowDebug.info("CameraImagePicker didFinishPickingMedia keys=\(info.keys.map { $0.rawValue }.joined(separator: ","))")
            if let image = info[.originalImage] as? UIImage {
                PhotoFlowDebug.info("CameraImagePicker original image received size=\(String(describing: image.size))")
                parent.onImagePicked(image)
            } else {
                PhotoFlowDebug.error("CameraImagePicker original image missing")
            }
            parent.dismiss()
            PhotoFlowDebug.info("CameraImagePicker dismissed after pick")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            PhotoFlowDebug.info("CameraImagePicker cancelled")
            parent.dismiss()
        }
    }
}
