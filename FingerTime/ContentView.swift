//
//  ContentView.swift
//  FingerTime
//
//  Created by oozoofrog on 5/3/26.
//

import PhotosUI
import SwiftUI
import UIKit
struct ContentView: View {
    @State private var clockModel = ClockTimeModel()
    @State private var photoStore = FacePhotoStore()

    @State private var sourceDialogSlot: PhotoSlot?
    @State private var pendingPhotoSlot: PhotoSlot?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingPhotoPicker = false
    @State private var isShowingCamera = false

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = proxy.size.width >= 700 ? 32 : 20
            let topPadding = proxy.safeAreaInsets.top + 18
            let bottomPadding = proxy.safeAreaInsets.bottom + 18
            let chromeHeight: CGFloat = 180
            let contentWidth = max(0, proxy.size.width - horizontalPadding * 2)
            let titleWidth = min(max(280, contentWidth - 230), 560)
            let toggleWidth: CGFloat = 174
            let clockAreaHeight = max(260, proxy.size.height - topPadding - bottomPadding - chromeHeight)
            let clockDiameter = min(contentWidth * 0.82, clockAreaHeight * 0.9, 720)
            let clockCenterY = topPadding + 82 + clockAreaHeight / 2

            ZStack {
                SpaceBackgroundView(background: clockModel.currentBackground)
                    .id(clockModel.currentBackground.id)

                ClockFaceView(
                    time: clockModel.displayedTime,
                    photoStore: photoStore,
                    diameter: clockDiameter,
                    onDragDelta: { hand, delta in
                        clockModel.applyDragDelta(delta, to: hand)
                    },
                    onPhotoTap: { slot in
                        PhotoFlowDebug.info("ContentView.onPhotoTap received slot=\(slot.rawValue)")
                        sourceDialogSlot = slot
                    }
                )
                .position(x: proxy.size.width / 2, y: clockCenterY)

                topTitle
                    .frame(width: titleWidth, alignment: .leading)
                    .position(x: horizontalPadding + titleWidth / 2, y: topPadding + 42)

                modeToggle
                    .frame(width: toggleWidth)
                    .position(x: proxy.size.width - horizontalPadding - toggleWidth / 2, y: topPadding + 42)

                photoSlotBar
                    .position(x: proxy.size.width / 2, y: proxy.size.height - bottomPadding - 72)

                photoAddFAB
                    .position(
                        x: proxy.size.width - horizontalPadding - 26,
                        y: proxy.size.height - bottomPadding - 72
                    )

                handPhotoFAB
                    .position(
                        x: proxy.size.width - horizontalPadding - 46,
                        y: proxy.size.height - bottomPadding - 145
                    )

                creditBar
                    .frame(width: contentWidth, alignment: .leading)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - bottomPadding - 22)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            PhotoFlowDebug.info("ContentView appeared")
        }
        .task {
            while !Task.isCancelled {
                await MainActor.run {
                    clockModel.tick()
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        .confirmationDialog(
            "얼굴 사진 선택",
            isPresented: sourceDialogBinding,
            presenting: sourceDialogSlot
        ) { slot in
            Button("사진 보관함에서 선택") {
                presentPhotoPicker(for: slot)
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("카메라로 찍기") {
                    presentCamera(for: slot)
                }
            } else {
                Button("카메라 사용 불가") {}
                    .disabled(true)
            }

            Button("취소", role: .cancel) {}
        } message: { slot in
            Text("\(slot.label) 위치에 넣을 사진을 선택하세요.")
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: sourceDialogSlot) { _, newSlot in
            logSourceDialogSlotChange(newSlot)
        }
        .onChange(of: pendingPhotoSlot) { _, newSlot in
            logPendingPhotoSlotChange(newSlot)
        }
        .onChange(of: isShowingPhotoPicker) { _, isShowing in
            logPhotoPickerPresentationChange(isShowing)
        }
        .onChange(of: isShowingCamera) { _, isShowing in
            logCameraPresentationChange(isShowing)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            handleSelectedPhotoItemChange(newItem)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker(onImagePicked: handleCameraImagePicked)
            .ignoresSafeArea()
            .onAppear(perform: logCameraSheetAppeared)
        }
    }

    private var sourceDialogBinding: Binding<Bool> {
        Binding(
            get: { sourceDialogSlot != nil },
            set: { isPresented in
                let slotName = sourceDialogSlot?.rawValue ?? "nil"
                PhotoFlowDebug.info("confirmationDialog binding set isPresented=\(isPresented) sourceSlot=\(slotName)")
                if !isPresented {
                    sourceDialogSlot = nil
                }
            }
        )
    }

    private func presentPhotoPicker(for slot: PhotoSlot) {
        PhotoFlowDebug.info("presentPhotoPicker requested slot=\(slot.rawValue)")
        pendingPhotoSlot = slot
        selectedPhotoItem = nil
        sourceDialogSlot = nil

        Task { @MainActor in
            PhotoFlowDebug.info("presentPhotoPicker waiting for dialog dismissal slot=\(slot.rawValue)")
            try? await Task.sleep(nanoseconds: 250_000_000)
            PhotoFlowDebug.info("presentPhotoPicker toggling picker true slot=\(slot.rawValue)")
            isShowingPhotoPicker = true
        }
    }

    private func presentCamera(for slot: PhotoSlot) {
        PhotoFlowDebug.info("presentCamera requested slot=\(slot.rawValue)")
        pendingPhotoSlot = slot
        sourceDialogSlot = nil

        Task { @MainActor in
            PhotoFlowDebug.info("presentCamera waiting for dialog dismissal slot=\(slot.rawValue)")
            try? await Task.sleep(nanoseconds: 250_000_000)
            PhotoFlowDebug.info("presentCamera toggling camera true slot=\(slot.rawValue)")
            isShowingCamera = true
        }
    }

    private func handleSelectedPhotoItemChange(_ newItem: PhotosPickerItem?) {
        let hasItem = newItem != nil
        let slotName = pendingPhotoSlot?.rawValue ?? "nil"
        PhotoFlowDebug.info("selectedPhotoItem changed hasItem=\(hasItem) pendingSlot=\(slotName)")
        guard let newItem, let pendingPhotoSlot else {
            PhotoFlowDebug.info("selectedPhotoItem ignored because item or pending slot is nil")
            return
        }

        Task {
            await loadSelectedPhotoItem(newItem, for: pendingPhotoSlot)
        }
    }

    private func loadSelectedPhotoItem(_ item: PhotosPickerItem, for slot: PhotoSlot) async {
        PhotoFlowDebug.info("PhotosPicker loadTransferable started slot=\(slot.rawValue)")
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                PhotoFlowDebug.error("PhotosPicker loadTransferable returned nil slot=\(slot.rawValue)")
                return
            }
            PhotoFlowDebug.info("PhotosPicker data loaded bytes=\(data.count) slot=\(slot.rawValue)")

            guard let image = UIImage(data: data) else {
                PhotoFlowDebug.error("PhotosPicker UIImage decode failed slot=\(slot.rawValue)")
                return
            }
            PhotoFlowDebug.info("PhotosPicker UIImage decoded size=\(String(describing: image.size)) slot=\(slot.rawValue)")

            await MainActor.run {
                PhotoFlowDebug.info("PhotosPicker saving image slot=\(slot.rawValue)")
                photoStore.save(image, for: slot)
                self.pendingPhotoSlot = nil
                selectedPhotoItem = nil
                PhotoFlowDebug.info("PhotosPicker save flow completed")
            }
        } catch {
            PhotoFlowDebug.error("PhotosPicker load failed error=\(error.localizedDescription) slot=\(slot.rawValue)")
        }
    }

    private func handleCameraImagePicked(_ image: UIImage) {
        guard let pendingPhotoSlot else {
            PhotoFlowDebug.error("Camera callback ignored because pendingPhotoSlot is nil")
            return
        }
        PhotoFlowDebug.info("Camera callback received image size=\(String(describing: image.size)) slot=\(pendingPhotoSlot.rawValue)")
        photoStore.save(image, for: pendingPhotoSlot)
        self.pendingPhotoSlot = nil
        PhotoFlowDebug.info("Camera save flow completed")
    }

    private func logSourceDialogSlotChange(_ slot: PhotoSlot?) {
        let slotName = slot?.rawValue ?? "nil"
        PhotoFlowDebug.info("sourceDialogSlot changed to \(slotName)")
    }

    private func logPendingPhotoSlotChange(_ slot: PhotoSlot?) {
        let slotName = slot?.rawValue ?? "nil"
        PhotoFlowDebug.info("pendingPhotoSlot changed to \(slotName)")
    }

    private func logPhotoPickerPresentationChange(_ isShowing: Bool) {
        PhotoFlowDebug.info("isShowingPhotoPicker changed to \(isShowing)")
    }

    private func logCameraPresentationChange(_ isShowing: Bool) {
        PhotoFlowDebug.info("isShowingCamera changed to \(isShowing)")
    }

    private func logCameraSheetAppeared() {
        let slotName = pendingPhotoSlot?.rawValue ?? "nil"
        PhotoFlowDebug.info("Camera sheet appeared pendingSlot=\(slotName)")
    }

    private var topTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FingerTime")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text("침을 돌려보면 시간이 함께 움직여요")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }

    private var modeToggle: some View {
        HStack(spacing: 14) {
            Text("조작 모드")
                .font(.headline.weight(.bold))
            Toggle("", isOn: $clockModel.isFreePlayMode)
                .labelsHidden()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.38), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.cyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }

    private var photoAddFAB: some View {
        Menu {
            ForEach(PhotoSlot.allCases) { slot in
                Button {
                    sourceDialogSlot = slot
                } label: {
                    Label {
                        Text(slot.label)
                    } icon: {
                        Text(slot.placeholder)
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.9), .purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.55), radius: 14)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
        }
    }

    private var handPhotoFAB: some View {
        Menu {
            ForEach(PhotoSlot.allCases.filter { $0 != .center }) { slot in
                Button {
                    sourceDialogSlot = slot
                } label: {
                    Label {
                        Text(slot.label)
                    } icon: {
                        Text(slot.placeholder)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 15, weight: .bold))
                Text("침 사진")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.9), .pink.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: .orange.opacity(0.5), radius: 12)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        }
    }

    private var photoSlotBar: some View {
        HStack(spacing: 20) {
            ForEach(PhotoSlot.allCases) { slot in
                Button {
                    sourceDialogSlot = slot
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                                )

                            if let image = photoStore.image(for: slot) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Text(slot.placeholder)
                                    .font(.system(size: 18))
                            }
                        }
                        .frame(width: 36, height: 36)

                        Text(slot.label)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.cyan.opacity(0.2), lineWidth: 1)
        )
    }

    private var creditBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
            Text(clockModel.currentBackground.title)
                .fontWeight(.bold)
                .lineLimit(1)
            Text("· \(clockModel.currentBackground.credit)")
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct SpaceBackgroundView: View {
    let background: NASASpaceBackground

    var body: some View {
        ZStack {
            DeepSpaceFallback()

            AsyncImage(url: background.url, transaction: Transaction(animation: .easeInOut(duration: 0.8))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                default:
                    DeepSpaceFallback()
                }
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.72),
                    .black.opacity(0.24),
                    .black.opacity(0.76)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 180,
                endRadius: 900
            )
            .ignoresSafeArea()
        }
    }
}

private struct DeepSpaceFallback: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.01, blue: 0.04),
                    Color(red: 0.03, green: 0.06, blue: 0.16),
                    Color(red: 0.01, green: 0.0, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                for index in 0..<140 {
                    let x = CGFloat((index * 53) % 997) / 997 * size.width
                    let y = CGFloat((index * 97) % 991) / 991 * size.height
                    let radius = CGFloat(index % 3 + 1) * 0.8
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(.white.opacity(index % 5 == 0 ? 0.9 : 0.48))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClockFaceView: View {
    var photoStore: FacePhotoStore

    let time: ClockTime
    let diameter: CGFloat
    let onDragDelta: (ClockHand, Double) -> Void
    let onPhotoTap: (PhotoSlot) -> Void

    @State private var activeHand: ClockHand?
    @State private var previousDragAngle: Double?

    init(
        time: ClockTime,
        photoStore: FacePhotoStore,
        diameter: CGFloat,
        onDragDelta: @escaping (ClockHand, Double) -> Void,
        onPhotoTap: @escaping (PhotoSlot) -> Void
    ) {
        self.time = time
        self.photoStore = photoStore
        self.diameter = diameter
        self.onDragDelta = onDragDelta
        self.onPhotoTap = onPhotoTap
    }

    var body: some View {
        let angles = ClockTimeMath.angles(for: time)
        let handLength = diameter * 0.34

        ZStack {
            ClockStaticFace(diameter: diameter).equatable()

            ClockHandLayer(
                angle: angles.hour,
                length: handLength * 0.68,
                width: diameter * 0.026,
                color: .purple,
                glow: .purple,
                slot: .hourHandTip,
                photoStore: photoStore,
                photoSize: diameter * 0.092,
                onPhotoTap: onPhotoTap
            )

            ClockHandLayer(
                angle: angles.minute,
                length: handLength * 0.96,
                width: diameter * 0.017,
                color: .cyan,
                glow: .cyan,
                slot: .minuteHandTip,
                photoStore: photoStore,
                photoSize: diameter * 0.088,
                onPhotoTap: onPhotoTap
            )

            ClockHandLayer(
                angle: angles.second,
                length: handLength * 1.08,
                width: diameter * 0.007,
                color: .orange,
                glow: .orange,
                slot: .secondHandTip,
                photoStore: photoStore,
                photoSize: diameter * 0.074,
                onPhotoTap: onPhotoTap
            )

            FacePhotoButton(
                slot: .center,
                image: photoStore.image(for: .center),
                size: diameter * 0.115,
                action: { onPhotoTap(.center) }
            )
        }
        .frame(width: diameter, height: diameter)
        .coordinateSpace(.named("clockFace"))
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named("clockFace"))
                .onChanged { value in
                    handleDrag(location: value.location, size: CGSize(width: diameter, height: diameter), angles: angles)
                }
                .onEnded { _ in
                    activeHand = nil
                    previousDragAngle = nil
                }
        )
        .shadow(color: .cyan.opacity(0.22), radius: 40)
    }

    private func handleDrag(location: CGPoint, size: CGSize, angles: ClockAngles) {
        let newAngle = ClockTimeMath.angle(for: location, in: size)

        if activeHand == nil {
            activeHand = nearestHand(to: newAngle, angles: angles)
            previousDragAngle = newAngle
            return
        }

        guard let activeHand, let previousDragAngle else {
            return
        }

        let delta = ClockTimeMath.shortestDeltaDegrees(from: previousDragAngle, to: newAngle)
        self.previousDragAngle = newAngle
        onDragDelta(activeHand, delta)
    }

    private func nearestHand(to angle: Double, angles: ClockAngles) -> ClockHand {
        let candidates: [(ClockHand, Double)] = [
            (.hour, ClockTimeMath.angularDistance(angle, angles.hour)),
            (.minute, ClockTimeMath.angularDistance(angle, angles.minute)),
            (.second, ClockTimeMath.angularDistance(angle, angles.second))
        ]
        return candidates.min(by: { $0.1 < $1.1 })?.0 ?? .minute
    }
}

private struct ClockStaticFace: View, Equatable {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            clockShell
            tickMarks
            clockNumbers
        }
    }

    private var clockShell: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .cyan.opacity(0.16),
                            .black.opacity(0.82),
                            .black.opacity(0.95)
                        ],
                        center: .center,
                        startRadius: diameter * 0.05,
                        endRadius: diameter * 0.5
                    )
                )

            Circle()
                .strokeBorder(.cyan.opacity(0.74), lineWidth: diameter * 0.018)

            Circle()
                .strokeBorder(.purple.opacity(0.35), lineWidth: diameter * 0.034)
                .blur(radius: 1)

            Circle()
                .inset(by: diameter * 0.085)
                .stroke(.white.opacity(0.13), style: StrokeStyle(lineWidth: 1.5, dash: [5, 8]))

            Circle()
                .inset(by: diameter * 0.18)
                .stroke(.cyan.opacity(0.13), lineWidth: 1)
        }
    }

    private var tickMarks: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let outerRadius = diameter * 0.438

            for index in 0..<60 {
                let isMajor = index.isMultiple(of: 5)
                let tickW: CGFloat = isMajor ? diameter * 0.008 : diameter * 0.004
                let tickH: CGFloat = isMajor ? diameter * 0.035 : diameter * 0.018
                let angleRad = Double(index) * 6 * .pi / 180

                let tx = cx + outerRadius * sin(angleRad)
                let ty = cy - outerRadius * cos(angleRad)

                var ctx = context
                ctx.addFilter(.shadow(color: .cyan.opacity(0.45), radius: 4))
                ctx.translateBy(x: tx, y: ty)
                ctx.rotate(by: .degrees(Double(index) * 6))

                let rect = CGRect(x: -tickW / 2, y: -tickH / 2, width: tickW, height: tickH)
                let color: Color = isMajor ? .white.opacity(0.92) : .cyan.opacity(0.55)
                ctx.fill(Path(roundedRect: rect, cornerRadius: tickW / 2), with: .color(color))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var clockNumbers: some View {
        ZStack {
            clockNumber("12", y: -diameter * 0.35)
            clockNumber("3", x: diameter * 0.35)
            clockNumber("6", y: diameter * 0.35)
            clockNumber("9", x: -diameter * 0.35)
        }
    }

    private func clockNumber(_ text: String, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        Text(text)
            .font(.system(size: diameter * 0.067, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .cyan, radius: 10)
            .shadow(color: .blue.opacity(0.8), radius: 22)
            .offset(x: x, y: y)
    }
}

private struct ClockHandLayer: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let glow: Color
    let slot: PhotoSlot
    var photoStore: FacePhotoStore
    let photoSize: CGFloat
    let onPhotoTap: (PhotoSlot) -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.95), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(width, 3), height: length)
                .offset(y: -length / 2)
                .shadow(color: glow.opacity(0.9), radius: 14)

            FacePhotoButton(
                slot: slot,
                image: photoStore.image(for: slot),
                size: photoSize,
                action: { onPhotoTap(slot) }
            )
            .offset(y: -length)
        }
        .rotationEffect(.degrees(angle))
    }
}

#Preview {
    ContentView()
}
