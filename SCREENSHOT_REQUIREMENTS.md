# Screenshot dimensions

All future simulator screenshot artifacts must use these exact portrait PNG dimensions:

| Device family | Required dimensions |
| --- | --- |
| iPhone | `1242 × 2688 px` |
| iPad | `2064 × 2752 px` |

`tools/normalize_screenshots.py` is the shared formatter used by both GitHub Actions screenshot workflows. It reads the XCTest attachment manifest, keeps descriptive capture names, preserves the full screenshot without cropping, and pads/resamples to the required canvas size. It also writes a dimension manifest and a local HTML gallery with every PNG's dimensions.

The visual-review workflow prefers a 13-inch iPad simulator. The App Store screenshots workflow captures on iPhone 17 and iPad Pro 13-inch (M5), then applies the same dimension check/normalization. The App Store upload helper uses these same target dimensions.
