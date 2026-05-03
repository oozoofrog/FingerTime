# FingerTime — AGENTS.md

> AI 코딩 에이전트(Cursor / Aider / Codex / Claude Code 등)를 위한 프로젝트 가이드.
> Claude Code 사용자는 `CLAUDE.md`를 우선 참조한다 (이 파일과 내용 동일).

## 프로젝트 개요

iPhone/iPad용 SwiftUI 인터랙티브 시계. 시계 침을 손가락으로 드래그해 시간을 직접 돌릴 수 있고, 시간이 바뀔 때마다 NASA 우주 배경이 회전한다. 시계 4개 슬롯에 사용자 사진을 붙일 수 있다.

## 빌드 & 테스트

```bash
xcodebuild -project FingerTime.xcodeproj -scheme FingerTime \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

xcodebuild -project FingerTime.xcodeproj -scheme FingerTime \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

- iOS 17.6+ / Swift 5.0 / Universal (iPhone+iPad)
- Xcode `FileSystemSynchronizedRootGroup` 사용 — 새 `.swift` 파일을 `FingerTime/`에 두면 자동 포함

## 디렉토리

```
FingerTime/                  # 앱 소스 (6개 파일)
  FingerTimeApp.swift        # @main
  ContentView.swift          # 메인 화면 + private View 모음
  ClockTime.swift            # 값 타입 + 무상태 수학(ClockTimeMath)
  ClockTimeModel.swift       # @MainActor ObservableObject
  SpaceBackgrounds.swift     # NASA 배경 + 회전 로직
  FacePhotos.swift           # 사진 저장/카메라/PhotosPicker
FingerTimeTests/             # Swift Testing (@Test)
FingerTimeUITests/           # XCUITest
FingerTime.xcodeproj/
```

## 핵심 설계

- **시간 표현**: `ClockTime.secondsSinceMidnight` 하나로 통일. 86,400 모듈로.
- **시계 수학 격리**: `enum ClockTimeMath`의 static 함수만 시각·각도·드래그를 다룬다 → 테스트 용이.
- **수동/자동 모드**: `ClockTimeModel.manualAnchor`로 마지막 수동 조작을 추적. `autoReturnDelay`(60s) 후 실제 시간 복귀, `isFreePlayMode` 시 영구 수동.
- **배경 회전**: `SpaceBackgroundRotator`가 `hourMarker` 변화에만 반응. 수동으로 시간을 돌려도 같은 규칙 적용.
- **사진 저장**: `Documents/FacePhotos/{slot}.jpg`, 정사각 크롭, JPEG 0.82.

## 스타일/관용

- `@MainActor` 명시.
- 새 SwiftUI 서브뷰는 가능한 같은 파일의 `private struct`로 시작. 별도 파일은 재사용/규모가 정당화될 때.
- 시계 수학 변경 시 `FingerTimeTests`의 회귀 테스트 추가 필수.
- 한국어 UI 문자열 유지 (`"침을 돌려보면 시간이 함께 움직여요"` 등).

## 작업 원칙

1. **단순함 우선** — 6개 파일짜리 앱이다. 새 추상화·새 파일·새 기능은 요청된 범위에서만.
2. **수술적 변경** — 인접 코드 임의 리팩토링 금지. 작동하는 코드는 건드리지 않는다.
3. **검증 후 완료 선언** — 빌드/테스트가 통과한 후에만 "완료"라고 말한다.
