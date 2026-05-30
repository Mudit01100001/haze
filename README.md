# Haze

> Noise-cancelling for your screen.

**Haze** is a lightweight macOS 26 Tahoe menubar app that helps you focus on one window at a time — controlled entirely by a cursor shake gesture.

Shake your mouse → everything fades behind a cinematic blur. Shake again → it's gone.

---

## Features

- 🖱 **Shake to focus** — cursor shake is the only interaction needed
- 🌫 **Real Gaussian blur** on live screen content (not a static screenshot)
- 🎞 **Film grain** (classic or chromatic aberration mode)
- 🎨 **Full color tint** — presets + custom color picker
- 🌑 **Grayscale mode** for background windows
- 🖼 **Custom alpha mask** — upload a BnW image to define gradient shape
- 💎 **Liquid Glass UI** — settings live in a native macOS 26 Tahoe popover
- 🆓 **MIT open source** — free forever

---

## Requirements

- macOS 26 Tahoe or later
- Accessibility permission (for cursor shake detection)
- Screen Recording permission (for the blur pipeline)

---

## Install

### Download
Grab the latest `.dmg` from [Releases](https://github.com/Mudit01100001/haze/releases).

### Homebrew
```bash
brew install --cask haze
```
*(Coming soon)*

---

## Build from source

```bash
git clone https://github.com/Mudit01100001/haze.git
cd haze
open Haze.xcodeproj
```

Requires Xcode 16+ and macOS 26 Tahoe SDK.

---

## How it works

Haze places a full-screen blur overlay *below* the active window using `NSWindow.orderWindow(.below, relativeTo:)`. No cutout, no mask tracking — the active window floats on top naturally. When you switch apps, Haze re-orders itself in one frame.

See [Haze_PRD.md](../Haze_PRD.md) for the full product spec.

---

## Privacy

Haze uses Screen Recording permission solely to generate the blur effect locally. No screen data ever leaves your machine.

---

## License

MIT © Mudit — see [LICENSE](LICENSE)
