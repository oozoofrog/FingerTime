//
//  SpaceBackgrounds.swift
//  FingerTime
//
//  Created by Codex on 5/3/26.
//

import Foundation

struct NASASpaceBackground: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let credit: String
    let url: URL

    init(id: String? = nil, title: String, credit: String, url: URL) {
        self.id = id ?? title
        self.title = title
        self.credit = credit
        self.url = url
    }
}

extension NASASpaceBackground {
    nonisolated static let curated: [NASASpaceBackground] = [
        NASASpaceBackground(
            id: "carina_nebula",
            title: "Cosmic Cliffs in Carina Nebula",
            credit: "NASA, ESA, CSA, STScI",
            url: URL(string: "https://images-assets.nasa.gov/image/carina_nebula/carina_nebula~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA25434",
            title: "Orion Nebula in Infrared",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA25434/PIA25434~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA13448",
            title: "A Flame in Orion's Belt",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA13448/PIA13448~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "GSFC_20171208_Archive_e000842",
            title: "Pillars of Creation",
            credit: "NASA, ESA, Hubble Heritage Team",
            url: URL(string: "https://images-assets.nasa.gov/image/GSFC_20171208_Archive_e000842/GSFC_20171208_Archive_e000842~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA03606",
            title: "Crab Nebula",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA03606/PIA03606~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "GSFC_20171208_Archive_e001651",
            title: "Hubble eXtreme Deep Field",
            credit: "NASA, ESA, Hubble",
            url: URL(string: "https://images-assets.nasa.gov/image/GSFC_20171208_Archive_e001651/GSFC_20171208_Archive_e001651~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA17009",
            title: "Center of the Milky Way",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA17009/PIA17009~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA04921",
            title: "Andromeda Galaxy",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA04921/PIA04921~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA03519",
            title: "Cassiopeia A",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA03519/PIA03519~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA13014",
            title: "Soul Nebula",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA13014/PIA13014~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA13123",
            title: "Hidden Star Cluster",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA13123/PIA13123~medium.jpg")!
        ),
        NASASpaceBackground(
            id: "PIA15256",
            title: "A Royal Celebration",
            credit: "NASA/JPL-Caltech",
            url: URL(string: "https://images-assets.nasa.gov/image/PIA15256/PIA15256~medium.jpg")!
        )
    ]
}

struct SpaceBackgroundRotator: Equatable {
    private let backgrounds: [NASASpaceBackground]
    private(set) var currentIndex: Int
    private var lastHour: Int

    init(backgrounds: [NASASpaceBackground] = NASASpaceBackground.curated, initialTime: ClockTime) {
        self.backgrounds = backgrounds.isEmpty ? NASASpaceBackground.curated : backgrounds
        currentIndex = 0
        lastHour = initialTime.hour
    }

    var current: NASASpaceBackground {
        backgrounds[currentIndex]
    }

    mutating func update(for time: ClockTime) {
        let newHour = time.hour
        guard newHour != lastHour else { return }
        let forward = (newHour - lastHour + 24) % 24
        let steps = forward <= 12 ? forward : forward - 24
        lastHour = newHour
        let count = backgrounds.count
        currentIndex = ((currentIndex + steps) % count + count) % count
    }
}
