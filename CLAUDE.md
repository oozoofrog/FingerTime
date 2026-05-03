# FingerTime

iPhone/iPad용 SwiftUI 인터랙티브 시계 앱. 시계 침을 손가락으로 드래그해 시간을 직접 돌릴 수 있고, 시간이 바뀔 때마다 NASA 우주 배경이 회전한다. 시계 위 4개 슬롯(중앙·시침끝·분침끝·초침끝)에 사용자 사진을 붙일 수 있다.

## Build & Test

```bash
# 시뮬레이터 빌드 (iPhone)
xcodebuild -project FingerTime.xcodeproj -scheme FingerTime \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# 단위 테스트 (Swift Testing)
xcodebuild -project FingerTime.xcodeproj -scheme FingerTime \
  -destination 'platform=iOS Simulator,name=iPhone 15' test

# 클린
xcodebuild -project FingerTime.xcodeproj -scheme FingerTime clean
```

- **Deployment target**: iOS 17.6+
- **Swift**: 5.0
- **Device family**: Universal (iPhone + iPad), `TARGETED_DEVICE_FAMILY = "1,2"`
- **Bundle ID**: `com.oozoofrog.macos.FingerTime`
- **Project format**: Xcode `FileSystemSynchronizedRootGroup` (파일 추가 시 `.pbxproj` 수동 편집 불필요)

## 아키텍처

단일 타겟, MVVM에 가까운 SwiftUI 구조. 6개 파일이 모두 `FingerTime/` 한 디렉토리에 있다.

| 파일 | 역할 |
|---|---|
| `FingerTimeApp.swift` | `@main` 진입점, `WindowGroup → ContentView` |
| `ContentView.swift` | 메인 화면. `ClockFaceView`/`ClockHandLayer`/`SpaceBackgroundView`/`DeepSpaceFallback`은 모두 같은 파일의 `private struct` |
| `ClockTime.swift` | 순수 값 타입 (`ClockTime`, `ClockHand`, `ClockAngles`) + 무상태 수학 (`enum ClockTimeMath`) |
| `ClockTimeModel.swift` | `@MainActor ObservableObject`. 표시 시간·자유 모드·배경 로테이터 보유 |
| `SpaceBackgrounds.swift` | `NASASpaceBackground.curated` (12장) + `SpaceBackgroundRotator` (시간대 변경 시 다음 인덱스로) |
| `FacePhotos.swift` | `PhotoSlot` enum, `FacePhotoStore` (Documents/FacePhotos/*.jpg), `FacePhotoButton`, `CameraImagePicker` |

### 시간 모델

- `ClockTime`은 `secondsSinceMidnight: TimeInterval` 하나로 시각을 표현. 86,400으로 모듈로 정규화.
- 모든 시계 수학은 `ClockTimeMath`의 static 함수에 격리되어 테스트 용이. 각도 ↔ 시간 변환, 드래그 델타 적용, 최단 회전 차이 계산.
- 시침 각도는 분/초까지 반영 (`hourRemainder / 43_200 * 360`) — 진짜 아날로그 시계처럼 시침이 연속적으로 움직인다.

### 조작 모드 (수동 vs 자동 복귀)

`ClockTimeModel`이 `manualAnchor: (time, date)?`로 마지막 수동 조작을 추적한다.

- 사용자가 침을 돌리면 `manualAnchor`가 설정되고, 이후 `tick()`은 anchor에 경과 시간을 더해 표시.
- `isFreePlayMode == false`이고 `autoReturnDelay`(기본 60초) 경과 시 anchor를 비우고 실제 시간으로 복귀.
- `isFreePlayMode == true`면 영구히 수동 시간이 흐른다.

### 배경 회전

`SpaceBackgroundRotator`는 `time.hourMarker`(0~23)가 바뀔 때만 다음 배경으로 넘어간다. 표시되는 시간(수동 포함)을 기준으로 하므로, 침을 돌려 시간을 1시간 이상 진행시켜도 배경이 즉시 바뀐다.

### 사진 저장

- `FacePhotoStore`는 `Documents/FacePhotos/{slot}.jpg`에 atomic write.
- 저장 시 `centerCroppedSquare(side: 512)`로 정사각 크롭. JPEG 품질 0.82.
- 카메라는 `UIImagePickerController` 래퍼 (`CameraImagePicker`), 갤러리는 SwiftUI `PhotosPicker`.

## 핵심 관용

- **순수 함수 우선**: 시계 수학과 배경 로테이션을 모델에서 분리해 테스트(`FingerTimeTests/`)에서 직접 검증한다.
- **`@MainActor` 명시**: UI 상태를 가진 모델은 모두 `@MainActor`. UIKit 인터롭(`CameraImagePicker.Coordinator`)도 메인 스레드 가정.
- **iPad 대응**: `ContentView`의 `GeometryReader`가 가로폭 700pt 기준으로 패딩과 시계 크기를 조정한다 (`clockDiameter = min(width * 0.82, height * 0.9, 720)`).
- **`#Preview` + Swift Testing**: 신규 SwiftUI/Testing 매크로 사용. 테스트는 XCTest 아님.

## 글로벌 규칙 (CLAUDE.md 우선)

`~/.claude/CLAUDE.md`의 4대 원칙(Think Before Coding · Simplicity First · Surgical Changes · Goal-Directed Execution)을 따른다. 특히:

- 6개 파일밖에 없으므로 **새 파일·새 추상화는 정당화 필요**. 같은 파일 안의 `private struct`로 충분한 경우가 많다.
- 시계 수학을 건드릴 때는 반드시 `FingerTimeTests`의 기존 케이스를 확인하고 회귀 테스트를 추가한다.
