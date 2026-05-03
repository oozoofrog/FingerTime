//
//  FacePhotos.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import Combine
import SwiftUI
import UIKit

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

@MainActor
final class FacePhotoStore: ObservableObject {
    @Published private(set) var images: [PhotoSlot: UIImage] = [:]

    private let directory: URL

    init(fileManager: FileManager = .default) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        directory = documents?.appendingPathComponent("FacePhotos", isDirectory: true) ?? fileManager.temporaryDirectory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        loadSavedImages()
    }

    func image(for slot: PhotoSlot) -> UIImage? {
        images[slot]
    }

    func save(_ image: UIImage, for slot: PhotoSlot) {
        let croppedImage = centerCroppedSquare(image)
        images[slot] = croppedImage
        guard let data = croppedImage.jpegData(compressionQuality: 0.82) else {
            return
        }
        try? data.write(to: fileURL(for: slot), options: [.atomic])
    }

    private func loadSavedImages() {
        for slot in PhotoSlot.allCases {
            if let image = UIImage(contentsOfFile: fileURL(for: slot).path) {
                images[slot] = image
            }
        }
    }

    private func fileURL(for slot: PhotoSlot) -> URL {
        directory.appendingPathComponent(slot.fileName)
    }

    private func centerCroppedSquare(_ image: UIImage, side: CGFloat = 512) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else {
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
        Button(action: action) {
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
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
