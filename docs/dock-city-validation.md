# Dock City validation record

## Provenance and environment

- Base: https://github.com/OSPK/Dockman
- SHA: `507398cbab2ead1f36c6f209d40f35a2ad1e9386`
- Branch: `dock-city`; reachable upstream history and MIT license retained. No push performed.
- Executor: Debian 13 x86_64 Linux; no Xcode, AppKit SDK or WindowServer.
- Toolchain: official Swift 6.0.3 Ubuntu 22.04 release, downloaded over verified HTTPS from download.swift.org.

## Automated checks

Initially, upstream build and test commands failed because Swift was absent.
After installation, an untouched upstream archive was built separately to identify
the platform blocker. That build failed at `import CoreGraphics` with
`no such module 'CoreGraphics'`, confirming the untouched original needs macOS.

The initial Dock City portable run executed 14 XCTest cases with zero failures:
6 CityKit cases and 8 original ConfigKit cases. One original case,
`testWriteRichDemoConfig`, is an opt-in helper and does no work unless `DOCKMAN_DEMO=1`.
It is not readiness evidence. The remaining 13 cases exercise legacy JSON defaults,
backup recovery, app state and missing IDs, day/night boundaries, persisted overrides,
actor bounds, entrance/exit states, and rapid activation retargeting.
No DockKit or SpacesKit tests executed on Linux.

To reproduce with the retained cloud toolchain from the repository root:

```bash
export PATH="/workspace/toolchains/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
export SWIFT_MODULECACHE_PATH=/workspace/toolchains/module-cache
export CLANG_MODULE_CACHE_PATH=/workspace/toolchains/clang-cache
export XDG_CACHE_HOME=/workspace/toolchains/cache
swift test --jobs 4 \
  --cache-path /workspace/toolchains/package-cache \
  --config-path /workspace/toolchains/package-config \
  --security-path /workspace/toolchains/package-security
```

Swift frontend syntax parsing, `bash -n scripts/make-app.sh` and `git diff --check`
are additional static checks; none establishes native AppKit type correctness.

Final Linux run: portable compilation and the same 14 XCTest cases passed with
zero failures (13 substantive cases plus the inactive demo helper). Every Swift
file in Sources/Tests passed frontend syntax parsing; shell syntax and diff
whitespace checks passed. Packaging was attempted and correctly refused Linux
with `Dock City packaging requires macOS 14+ and Xcode.` No `.app` was generated.

## Required Mac validation — pending

In a GUI login session, run:

```bash
swift build --jobs 4
swift test --jobs 4
swift run dockman-spike --once
./scripts/make-app.sh app release
codesign --verify --strict --verbose=2 'build/Dock City.app'
open 'build/Dock City.app'
```

New `CityLayoutTests` checks actual cell center alignment and identity on reorder,
crowded Dock fitting, and a click-through decoration panel that hides when disabled.
Those tests have not executed here. The macOS workflow runs the full suite and builds
an ad-hoc signed app artifact, but has not been triggered by this task.

Manual scenarios (all pending):

- Finder/Safari/Terminal/Music/Calendar have distinct roofs, windows and doors.
- Launch, quit and quickly switch apps; only matching lights respond.
- Verify unknown apps and missing bundle IDs, pinned and transient running items.
- Click icons, reorder, pin/unpin apps, drop files and open folder stacks.
- Resize/reorder Docks, magnify icons and use 30+ items; verify exact alignment.
- Observe citizen walking/entry/exit and delivery stops after real app activation.
- Force day/night; test automatic transitions, local timezone changes and wake.
- Change every city control, quit/relaunch, and verify saved per-app choices.
- Switch Spaces/fullscreen, auto-hide, attach/detach monitors and test all edges.
- Verify Reduce Motion, macOS Low Power and paused rendering while hidden.
- Measure CPU, memory and energy over a long session; no numbers are claimed here.
- Confirm original Dockman settings and URL handler remain untouched.

This is an implemented development version, not a verified Dock City v1.0 release.
No `.app`, notarization or native GUI execution is claimed in this Linux environment.
