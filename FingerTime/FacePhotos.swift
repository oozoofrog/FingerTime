//
//  FacePhotos.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import SwiftUI
import UIKit
import Vision
import Photos

enum PhotoSlot: String, CaseIterable, Identifiable {
    case center
    case hourHandTip
    case minuteHandTip
    case secondHandTip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .center: "중앙"
        case .hourHandTip: "시침"
        case .minuteHandTip: "분침"
        case .secondHandTip: "초침"
        }
    }

    var placeholder: String {
        switch self {
        case .center: "🧒"
        case .hourHandTip: "👨"
        case .minuteHandTip: "👩"
        case .secondHandTip: "⭐️"
        }
    }

    var fileName: String { "\(rawValue).jpg" }
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
        } catch {
            PhotoFlowDebug.error("FacePhotoStore directory create failed error=\(error.localizedDescription)")
        }
        loadSavedImages()
    }

    func image(for slot: PhotoSlot) -> UIImage? { images[slot] }

    func save(_ image: UIImage, for slot: PhotoSlot) {
        PhotoFlowDebug.info("FacePhotoStore save slot=\(slot.rawValue)")
        let cropped: UIImage
        if let center = detectFaceCenter(in: image) {
            cropped = faceCroppedSquare(image, faceCenter: center)
        } else {
            cropped = centerCroppedSquare(image)
        }
        guard let data = cropped.jpegData(compressionQuality: 0.82) else { return }
        let dest = fileURL(for: slot)
        do {
            try data.write(to: dest, options: [.atomic])
        } catch {
            PhotoFlowDebug.error("FacePhotoStore save failed slot=\(slot.rawValue) error=\(error.localizedDescription)")
        }
        images[slot] = cropped
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

    private func detectFaceCenter(in image: UIImage) -> CGPoint? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])
        guard let face = request.results?
            .max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
        else { return nil }
        let box = face.boundingBox
        return CGPoint(x: box.midX * image.size.width, y: (1 - box.midY) * image.size.height)
    }

    private func faceCroppedSquare(_ image: UIImage, faceCenter: CGPoint, side: CGFloat = 512) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let scale = max(side / image.size.width, side / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawX = min(0, max(side - scaledSize.width, side / 2 - faceCenter.x * scale))
        let drawY = min(0, max(side - scaledSize.height, side / 2 - faceCenter.y * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(x: drawX, y: drawY, width: scaledSize.width, height: scaledSize.height))
        }
    }

    private func centerCroppedSquare(_ image: UIImage, side: CGFloat = 512) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let scale = max(side / image.size.width, side / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(
                x: (side - scaledSize.width) / 2, y: (side - scaledSize.height) / 2,
                width: scaledSize.width, height: scaledSize.height
            ))
        }
    }
}

// MARK: - FacePhotoButton

struct FacePhotoButton: View {
    let slot: PhotoSlot
    let image: UIImage?
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: max(3, size * 0.07)))
                    .shadow(color: .cyan.opacity(0.65), radius: 14)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(slot.placeholder).font(.system(size: size * 0.48))
                }
                Circle().strokeBorder(.cyan.opacity(0.55), lineWidth: 2)
            }
            .frame(width: size, height: size)
            .accessibilityLabel("\(slot.label) 얼굴 사진 선택")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Photo Album Picker

struct PhotoAlbum: Identifiable {
    let id: String
    let title: String
    let collection: PHAssetCollection?
    let count: Int
    let coverAsset: PHAsset?
}

struct CustomPhotoPicker: View {
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var albums: [PhotoAlbum] = []

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized, .limited:
                    albumList
                case .denied, .restricted:
                    deniedView
                default:
                    ProgressView("권한 요청 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                }
            }
            .navigationTitle("앨범")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(.cyan)
                }
            }
        }
        .task { await requestAndLoad() }
    }

    private var albumList: some View {
        Group {
            if albums.isEmpty {
                ProgressView("불러오는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                List(albums) { album in
                    NavigationLink {
                        AlbumPhotosGrid(album: album) { image in
                            onImagePicked(image)
                            dismiss()
                        }
                    } label: {
                        AlbumRow(album: album)
                    }
                    .listRowBackground(Color.black)
                    .listRowSeparatorTint(.white.opacity(0.1))
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("사진 접근 권한 없음", systemImage: "photo.slash")
        } description: {
            Text("설정 앱에서 FingerTime의 사진 접근을 허용해 주세요.")
        } actions: {
            Button("설정 열기") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
    }

    private func requestAndLoad() async {
        if authStatus != .authorized && authStatus != .limited {
            authStatus = await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
            }
        }
        guard authStatus == .authorized || authStatus == .limited else { return }
        albums = buildAlbumList()
    }

    private func buildAlbumList() -> [PhotoAlbum] {
        var result: [PhotoAlbum] = []
        let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let recentFirst = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // 최근 항목 (all photos)
        let allOpts = PHFetchOptions()
        allOpts.predicate = imagePredicate
        let allFetch = PHAsset.fetchAssets(with: .image, options: allOpts)
        if allFetch.count > 0 {
            result.append(PhotoAlbum(id: "__all__", title: "최근 항목",
                                     collection: nil, count: allFetch.count,
                                     coverAsset: allFetch.firstObject))
        }

        // User albums
        PHAssetCollection
            .fetchAssetCollections(with: .album, subtype: .any, options: nil)
            .enumerateObjects { col, _, _ in
                let opts = PHFetchOptions(); opts.predicate = imagePredicate
                let count = PHAsset.fetchAssets(in: col, options: opts).count
                guard count > 0 else { return }
                let coverOpts = PHFetchOptions()
                coverOpts.sortDescriptors = recentFirst; coverOpts.fetchLimit = 1
                result.append(PhotoAlbum(id: col.localIdentifier, title: col.localizedTitle ?? "앨범",
                                         collection: col, count: count,
                                         coverAsset: PHAsset.fetchAssets(in: col, options: coverOpts).firstObject))
            }

        // Smart albums
        for (subtype, title) in [(PHAssetCollectionSubtype.smartAlbumFavorites, "즐겨찾기"),
                                  (.smartAlbumSelfPortraits, "셀카"),
                                  (.smartAlbumScreenshots, "스크린샷")] {
            guard let col = PHAssetCollection
                .fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil).firstObject
            else { continue }
            let opts = PHFetchOptions(); opts.predicate = imagePredicate
            let count = PHAsset.fetchAssets(in: col, options: opts).count
            guard count > 0 else { continue }
            let coverOpts = PHFetchOptions()
            coverOpts.sortDescriptors = recentFirst; coverOpts.fetchLimit = 1
            result.append(PhotoAlbum(id: col.localIdentifier, title: title, collection: col,
                                     count: count,
                                     coverAsset: PHAsset.fetchAssets(in: col, options: coverOpts).firstObject))
        }

        return result
    }
}

private struct AlbumRow: View {
    let album: PhotoAlbum
    @State private var cover: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Color.gray.opacity(0.25)
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title).font(.body.weight(.medium)).foregroundStyle(.white)
                Text("\(album.count)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear { loadCover() }
    }

    private func loadCover() {
        guard cover == nil, let asset = album.coverAsset else { return }
        if let cached = PhotoThumbnailCache.shared.image(for: asset.localIdentifier) {
            cover = cached
            return
        }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = false
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill, options: opts
        ) { image, _ in
            guard let image else { return }
            PhotoThumbnailCache.shared.store(image, for: asset.localIdentifier)
            Task { @MainActor in cover = image }
        }
    }
}

private struct AlbumPhotosGrid: View {
    let album: PhotoAlbum
    let onImagePicked: (UIImage) -> Void

    @State private var assets: [PHAsset] = []
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    PhotoThumbnailCell(asset: asset, onSelect: onImagePicked)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { assets = fetchAssets() }
    }

    private func fetchAssets() -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let fetch: PHFetchResult<PHAsset> = album.collection.map {
            PHAsset.fetchAssets(in: $0, options: opts)
        } ?? PHAsset.fetchAssets(with: .image, options: opts)
        var result: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in result.append(asset) }
        return result
    }
}

private struct PhotoThumbnailCell: View {
    let asset: PHAsset
    let onSelect: (UIImage) -> Void

    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Button { loadFullImage() } label: {
            Color.gray.opacity(0.2)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    }
                }
                .clipped()
        }
        .buttonStyle(.plain)
        .onAppear { loadThumbnail() }
        .onDisappear { cancelThumbnail() }
    }

    private func loadThumbnail() {
        if let cached = PhotoThumbnailCache.shared.image(for: asset.localIdentifier) {
            thumbnail = cached
            return
        }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = false
        requestID = PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 220, height: 220),
            contentMode: .aspectFill, options: opts
        ) { image, _ in
            guard let image else { return }
            PhotoThumbnailCache.shared.store(image, for: asset.localIdentifier)
            Task { @MainActor in
                thumbnail = image
                requestID = nil
            }
        }
    }

    private func cancelThumbnail() {
        guard let id = requestID else { return }
        PHImageManager.default().cancelImageRequest(id)
        requestID = nil
    }

    private func loadFullImage() {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit, options: opts
        ) { image, info in
            guard let image, info?[PHImageResultIsDegradedKey] as? Bool != true else { return }
            Task { @MainActor in onSelect(image) }
        }
    }
}

// MARK: - Thumbnail Cache

private final class PhotoThumbnailCache {
    static let shared = PhotoThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 300 }

    func image(for id: String) -> UIImage? { cache.object(forKey: id as NSString) }
    func store(_ image: UIImage, for id: String) { cache.setObject(image, forKey: id as NSString) }
}

// MARK: - Camera Picker

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

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) { self.parent = parent }

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
