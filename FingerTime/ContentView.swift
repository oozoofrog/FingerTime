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
    @StateObject private var clockModel = ClockTimeModel()
    @StateObject private var photoStore = FacePhotoStore()

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
            let chromeHeight: CGFloat = 124
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

                creditBar
                    .frame(width: contentWidth, alignment: .leading)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - bottomPadding - 26)
            }
        }
        .preferredColorScheme(.dark)
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
            isPresented: Binding(
                get: { sourceDialogSlot != nil },
                set: { isPresented in
                    if !isPresented {
                        sourceDialogSlot = nil
                    }
                }
            ),
            presenting: sourceDialogSlot
        ) { slot in
            Button("사진 보관함에서 선택") {
                pendingPhotoSlot = slot
                sourceDialogSlot = nil
                isShowingPhotoPicker = true
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("카메라로 찍기") {
                    pendingPhotoSlot = slot
                    sourceDialogSlot = nil
                    isShowingCamera = true
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem, let pendingPhotoSlot else {
                return
            }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        photoStore.save(image, for: pendingPhotoSlot)
                        self.pendingPhotoSlot = nil
                        selectedPhotoItem = nil
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker { image in
                guard let pendingPhotoSlot else {
                    return
                }
                photoStore.save(image, for: pendingPhotoSlot)
                self.pendingPhotoSlot = nil
            }
            .ignoresSafeArea()
        }
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
    @ObservedObject var photoStore: FacePhotoStore

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
            clockShell
            tickMarks
            clockNumbers

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
        .coordinateSpace(name: "clockFace")
        .gesture(
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
        ZStack {
            ForEach(0..<60, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 5) ? .white.opacity(0.92) : .cyan.opacity(0.55))
                    .frame(
                        width: index.isMultiple(of: 5) ? diameter * 0.008 : diameter * 0.004,
                        height: index.isMultiple(of: 5) ? diameter * 0.035 : diameter * 0.018
                    )
                    .offset(y: -diameter * 0.438)
                    .rotationEffect(.degrees(Double(index) * 6))
                    .shadow(color: .cyan.opacity(0.45), radius: 4)
            }
        }
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

private struct ClockHandLayer: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let glow: Color
    let slot: PhotoSlot
    @ObservedObject var photoStore: FacePhotoStore
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
