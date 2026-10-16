# Priviewer

[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC_BY--NC_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)

Watch videos stored on your computer from an iPhone or iPad, either by streaming them over the network or downloading them for offline playback.

Priviewer has two parts: a small Python video server and a native SwiftUI client. Enable Auto-Sync to cache newer videos when the app observes that the device is charging and connected to Wi-Fi, or save individual videos for offline use.

## Features

- Browse the server's video list and stream with HTTP byte-range seeking.
- Play cached videos locally.
- Manually synchronize or enable charging-and-Wi-Fi automatic synchronization.
- Keep an automatic cache of newer videos within a **3 GiB** budget (shown as approximately 3 GB in the app).
- Pin individual videos to keep them outside the automatic cache budget.
- View transfer progress, stop synchronization, and inspect cache usage.

## Supported platforms

| Component | Platforms and requirements |
| --- | --- |
| Video server | Windows is the documented primary host. The Python/Flask/Waitress implementation is also portable to macOS and Linux with Python 3.10 or later; validate deployment on those hosts. |
| Client | iPhone on iOS 17 or later; the Xcode target also enables iPad on iPadOS 17 or later. |
| Client build machine | Mac with Xcode 15 or later and an SDK/toolchain capable of building the checked-in source. Use a current Xcode if the compiler rejects newer source syntax. |
| Other clients | No Android or native Windows client is included. |

The server indexes `.mp4`, `.mov`, `.avi`, `.mkv`, `.m4v`, `.wmv`, `.flv`, and `.webm`. Indexing a file does not guarantee that Apple's native player supports its container/codecs. The server sends original files without transcoding; MP4 with H.264/AAC is a practical starting point.

## Deploy the video server

### 1. Choose a video folder

Copy `server.py` and `requirements.txt` into the folder containing the videos you want to serve.

**The server scans the directory containing `server.py`, not the terminal's current directory.** It lists files immediately inside that folder; it does not recursively scan subfolders.

### 2. Install dependencies and start

Run from that folder.

**Windows PowerShell:**

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe server.py
```

**macOS / Linux:**

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python server.py
```

The server uses Waitress by default, listens on all interfaces, and prints an address such as `http://192.168.1.50:8765`. Allow inbound TCP port **8765** through the host's firewall for your private network. A custom port is supported:

```sh
python server.py --port 9000
```

Use the virtual environment's Python for that command. `--dev` selects the Flask development server. Optional `ffprobe`, installed with FFmpeg and available on `PATH`, enables duration metadata in the video list.

### 3. Check connectivity

From another device on the LAN, open:

```text
http://192.168.1.50:8765/videos
```

Replace the example IP with the server's physical LAN address. This endpoint returns a JSON list, rather than a browser player. Keep the server process and computer awake while streaming or downloading.

## Deploy the iPhone / iPad app

1. On a Mac, open `PriviewerApp/PriviewerApp.xcodeproj` in Xcode.
2. Select the app target, choose your development team under **Signing & Capabilities**, and use a unique bundle identifier if necessary.
3. Connect the iPhone/iPad, complete device trust/developer-mode setup if prompted, and select it as the run destination.
4. Build and run the `PriviewerApp` scheme.
5. In the app, open **Settings** using the gear icon and enter the server URL, for example `http://192.168.1.50:8765`.
6. Allow local-network access if prompted, then refresh the video list.

Use the computer's LAN IP, not `localhost`: on the phone, `localhost` refers to the phone itself. Xcode deployment requires the usual Apple signing setup; there is no prebuilt App Store/TestFlight distribution supplied here.

## Offline playback and synchronization

- **Automatic:** enable **Auto-Sync**, connect to Wi-Fi, and plug the device into power. Keep the app open for initial synchronization.
- **Manual:** use **Settings → Sync Now** to start immediately.
- **Pinned videos:** use a video's save action to download and retain it independently of the automatic budget. Pinned files can make total cache usage exceed 3 GiB.
- **Automatic selection:** the server sorts its manifest newest-first by file modification time. The client chooses files that fit within the budget and evicts unpinned cached files outside that selection.
- **Playback:** cached files play locally; other files stream from the server.

iOS controls background execution. Charging and Wi-Fi conditions alone do not guarantee that synchronization will start or finish while the app is suspended; use Sync Now with the app open when you need a predictable download.

## Remote access

The existing design can use an externally configured tunnel such as `wstunnel`: forward the server's single TCP port, then enter the reachable tunneled URL in the app. Listing, streaming, and synchronization all use that endpoint.

The server has no built-in login or TLS. For access outside a trusted LAN, place authentication and encryption in the tunnel/VPN/reverse proxy. Tunnel provisioning is external to this repository.

## API

| Endpoint | Purpose |
| --- | --- |
| `GET /videos` | Video list with filenames, sizes, modification times, and optional durations |
| `GET` / `HEAD /videos/<name>` | Original video bytes and metadata; GET supports byte ranges |
| `GET /sync/manifest` | Newest-first file metadata for cache selection |

## Troubleshooting

- **Cannot connect:** check that the server is running, its IP/port are correct, both devices can reach the same LAN, and the firewall allows TCP access. A VPN can change the address printed by the server; use its actual LAN IP.
- **Empty list:** place videos beside `server.py`, check their extensions, and refresh.
- **Video lists but will not play:** check native Apple codec/container compatibility; this server does not convert files.
- **Auto-Sync does not start:** check the toggle, Wi-Fi, and charging state, then try Sync Now in the foreground.
- **Need diagnostics:** open **Settings → Developer → Debug Console**.

## License

Copyright © 2026 Lucaslu2010, for original contributions.

Except for third-party material and files with a separate license notice, the
original project source code and documentation are licensed under
[Creative Commons Attribution-NonCommercial 4.0 International
(CC BY-NC 4.0)](https://creativecommons.org/licenses/by-nc/4.0/).
See [LICENSE](LICENSE) for the full legal text.

You may share and adapt the covered material for noncommercial purposes, provided
you give appropriate credit, link to the license, and indicate changes. Commercial
uses requiring permission under copyright are not granted by this license; seek
separate permission from the relevant rights holder. The full license, including
its exceptions and limitations, governs.

Third-party code, assets, and dependencies retain their own licenses. This notice
does not replace those licenses or restrict rights they independently grant.

Python dependencies and Apple platform components remain subject to their
respective licenses; they are not relicensed by this repository.

## Acknowledgments

Documentation and publication preparation assisted by OpenAI Codex.
