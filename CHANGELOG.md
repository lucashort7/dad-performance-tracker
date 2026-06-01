# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.3] - 2026-06-01

## [1.1.3] - 2026-06-01

## [1.1.2] - 2026-06-01

## [1.1.1] - 2026-06-01

### Added

- **Results Badge:** Stylized high-score indicator on the end-of-song screen.
- **Atomic History:** New JSON-based persistence system with atomic writes to prevent data corruption.
- **Combat Pipeline:** Granular tracking for Perfect vs. Normal hits across all player abilities.
- **Mocking Tool:** Developer shortcut (F6) to test results UI without full playthroughs.
- **Dynamic UI:** Real-time accuracy and combo tracking HUD during gameplay.

### Fixed

- **Invisible Widget Bug:** Resolved UI hierarchy issues where borders wouldn't render correctly.
- **Data Race Conditions:** Fixed PB comparisons failing due to late score polling.
- **Zero-score Glitch:** Fixed an issue where dying mid-song would wipe historical data.

## [1.0.0] - 2026-06-01

### Initial Release

- Performance tracking engine for Dead as Disco.
- Accuracy and Combo monitoring.
- HighScore persistence.

[unreleased]: https://github.com/lucashort7/dad-performance-tracker/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/lucashort7/dad-performance-tracker/compare/v1.1.3...v1.1.3
[1.1.3]: https://github.com/lucashort7/dad-performance-tracker/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/lucashort7/dad-performance-tracker/compare/1.1.1...v1.1.2
[1.1.1]: https://github.com/lucashort7/dad-performance-tracker/compare/b223d0137355dfe54bee9371b03a50613bc9b704...1.1.1
