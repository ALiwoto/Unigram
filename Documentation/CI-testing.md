## CI build and tester notes

This repository includes a GitHub Actions workflow at `.github/workflows/build-unigram.yml` intended to build Unigram in CI and upload build artifacts.

## What the workflow builds

- `x64` only
- Calls support enabled
- TDLib built in CI
- WebRTC built in CI
- LibVLC built in CI and packed as a local NuGet package
- MSIX/AppX artifacts uploaded from the workflow run

ARM/ARM64 is intentionally not built by this workflow.

## Why LibVLC is handled specially

The checked-in `Libraries/vlc/VideoLAN.LibVLC.UWP.nuspec` expects both `x64` and `ARM64` VLC outputs.

Because this workflow only builds `x64`, CI first generates an `x64`-only nuspec and packs that instead. This avoids forcing an unnecessary ARM build just to satisfy the package layout.

## Caching

The workflow caches the expensive dependency layers:

- LibVLC build output
- `vcpkg` downloads, packages, installed tree, and binary cache
- TDLib output
- WebRTC source tree and build output
- NuGet caches

The goal is to make the first run expensive, then keep later runs practical.

## API configuration behavior

The workflow generates `Telegram/Constants.Secret.cs` through `scripts/ci/write-constants-secret.ps1`.

It supports two modes:

1. CI-secret mode
   - Uses `UNIGRAM_API_ID`
   - Uses `UNIGRAM_API_HASH`
   - Uses `UNIGRAM_APP_CHANNEL`

2. Local tester mode
   - If all three variables are omitted, the generated code reads `api.json` from the app's `LocalState` folder at runtime

Partial configuration is rejected on purpose. The three values must be either all provided or all omitted.

## Local tester setup

If a tester installs a CI-produced package without embedded API values, they must create `api.json` inside the app's `LocalState` folder.

Expected file contents:

```json
{
  "ApiId": 12345,
  "ApiHash": "your_api_hash",
  "AppChannel": "your_channel"
}
```

Typical path:

```text
%LOCALAPPDATA%\Packages\<PackageFamilyName>\LocalState\api.json
```

The exact package family name depends on the manifest identity used by the package being installed.

## Notes for maintainers

- This workflow is designed for GitHub-hosted runners and does not require local compilation on the contributor machine.
- The WebRTC build scripts in the repository assume a fixed Visual Studio path, so the workflow adapts the runner layout to match that expectation.
- The workflow currently targets CI artifact production, not Microsoft Store publishing.
