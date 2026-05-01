#!/usr/bin/env bash

set -euo pipefail

archive_path="${1:?expected output archive path}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vlc_root="$repo_root/Libraries/vlc"
submodule_root="$vlc_root/vlc"
docker_image="${VLC_DOCKER_IMAGE:-registry.videolan.org/vlc-debian-llvm-uwp:20211020111246}"

mkdir -p "$(dirname "$archive_path")"

mapfile -t patches < <(find "$vlc_root" -maxdepth 1 -name '*.patch' | sort)

for patch in "${patches[@]}"; do
  git -C "$submodule_root" apply --3way --ignore-space-change --ignore-whitespace "$patch"
done

mkdir -p "$submodule_root/src"
cp "$vlc_root/revision.txt" "$submodule_root/src/revision.txt"

docker run --rm \
  -v "$submodule_root:/vlc" \
  "$docker_image" \
  bash -lc 'set -euo pipefail; cd /vlc; extras/package/win32/build.sh -a x86_64 -z -r -u -w -D=/vlc'

test -d "$submodule_root/win64-uwp/vlc-3.0.22-rc1"

tar -C "$repo_root" -czf "$archive_path" Libraries/vlc/vlc/win64-uwp/vlc-3.0.22-rc1
