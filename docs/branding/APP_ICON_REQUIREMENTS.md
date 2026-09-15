# Nono Cleaner App Icon Requirements

Nono Cleaner does not yet have a final production icon. This document defines the deliverables for the first public beta without choosing or generating the brand artwork.

## Master Artwork

- Create one 1024 × 1024 px master in an editable source format.
- Export in the sRGB color space.
- Keep critical artwork comfortably inside the central area (approximately 80%) so it remains legible after macOS applies its icon mask.
- Do not bake a rounded-rectangle mask or transparent rounded corners into the artwork.
- Avoid fine text and details that disappear at 16 px.

## Required macOS Icon Files

| Filename | Pixel dimensions |
| --- | ---: |
| `icon_16x16.png` | 16 × 16 |
| `icon_16x16@2x.png` | 32 × 32 |
| `icon_32x32.png` | 32 × 32 |
| `icon_32x32@2x.png` | 64 × 64 |
| `icon_128x128.png` | 128 × 128 |
| `icon_128x128@2x.png` | 256 × 256 |
| `icon_256x256.png` | 256 × 256 |
| `icon_256x256@2x.png` | 512 × 512 |
| `icon_512x512.png` | 512 × 512 |
| `icon_512x512@2x.png` | 1024 × 1024 |

Place approved PNG exports in `Resources/AppIcon.iconset/`, then generate an `.icns` file with `iconutil`. The build must not reference an icon until all required files and the final artwork have been reviewed.

## Visual QA

- Test in Finder at 16, 32, 64, 128, 256, 512, and 1024 px.
- Test against both light and dark desktop backgrounds.
- Test in the Dock, Finder list view, Launchpad, and the app switcher.
- Confirm the silhouette, contrast, and main visual remain identifiable at the smallest sizes.
- Confirm no private filenames, user data, third-party trademarks, or unlicensed assets are embedded.
