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

# VLC 3.0.x hardcodes a specific SourceForge mirror that is no longer reliable
# on GitHub-hosted runners. Use the generic redirector instead.
sed -i 's|^SF := https://netcologne\.dl\.sourceforge\.net/$|SF := https://downloads.sourceforge.net/project|' \
  "$submodule_root/contrib/src/main.mak"

# The -r flag in VLC 3.0.x enables release mode and also asks build.sh to run
# the full Windows installer packaging target. The NuGet package only needs the
# staged LibVLC tree, so keep release mode but package the needed target below.
sed -i 's|^\([[:space:]]*\)INSTALLER="r"$|\1:|' \
  "$submodule_root/extras/package/win32/build.sh"

mkdir -p "$submodule_root/src"
cp "$vlc_root/revision.txt" "$submodule_root/src/revision.txt"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$submodule_root:/vlc:rw" \
  "$docker_image" \
  bash -c '
    set -euo pipefail

    dump_diagnostics() {
      status=$?
      if [ "$status" -ne 0 ]; then
        echo "::group::VLC toolchain diagnostics"
        echo "PATH=$PATH"
        for candidate in clang clang++ llvm-ar llvm-ranlib llvm-strip llvm-nm llvm-objdump llvm-rc llvm-dlltool; do
          printf "%s -> " "$candidate"
          command -v "$candidate" || true
        done
        for tool in gcc g++ cpp ld ar ranlib strip nm as dlltool objdump windres widl; do
          uwp="x86_64-w64-mingw32uwp-$tool"
          printf "%s -> " "$uwp"
          command -v "$uwp" || true
        done
        find /opt /usr/local /usr -maxdepth 4 -type f \
          \( -name "x86_64*w64*mingw*" -o -name "i686*w64*mingw*" -o -name "clang*" -o -name "llvm-*" \) \
          2>/dev/null | sort | head -n 200 || true
        echo "::endgroup::"

        if [ -d /vlc/contrib ]; then
          while IFS= read -r log; do
            echo "::group::$log"
            tail -n 200 "$log" || true
            echo "::endgroup::"
          done < <(find /vlc/contrib -name config.log -type f 2>/dev/null | sort | tail -n 10)
        fi
      fi
      exit "$status"
    }
    trap dump_diagnostics EXIT

    shim_dir=/tmp/toolchain-shims
    contrib_shim_dir=/vlc/contrib/x86_64-w64-mingw32uwp/bin
    mkdir -p "$shim_dir" "$contrib_shim_dir"

    create_uwp_shim() {
      uwp="$1"
      base="$2"
      base_path="$(command -v "$base" || true)"
      if [ -z "$base_path" ]; then
        echo "Skipping $uwp shim because $base was not found"
        return
      fi

      for target_dir in "$shim_dir" "$contrib_shim_dir"; do
        cat > "$target_dir/$uwp" <<EOF
#!/bin/sh
exec "$base_path" "\$@"
EOF
        chmod +x "$target_dir/$uwp"
      done
    }

    for tool in gcc g++ cpp ld ar ranlib strip nm as dlltool objdump windres widl objcopy readelf addr2line strings size; do
      create_uwp_shim "x86_64-w64-mingw32uwp-$tool" "x86_64-w64-mingw32-$tool"
    done

    create_uwp_shim x86_64-w64-mingw32uwp-cc x86_64-w64-mingw32-gcc
    create_uwp_shim x86_64-w64-mingw32uwp-c++ x86_64-w64-mingw32-g++

    export PATH="$shim_dir:$contrib_shim_dir:$PATH"
    command -v x86_64-w64-mingw32uwp-gcc
    x86_64-w64-mingw32uwp-gcc --version | sed -n "1p"
    printf "" | x86_64-w64-mingw32uwp-gcc -x c -E - >/dev/null

    cd /vlc
    extras/package/win32/build.sh -a x86_64 -z -r -u -w -D /vlc
    make -C win64-uwp package-win-strip
  '

test -d "$submodule_root/win64-uwp/vlc-3.0.22-rc1"

tar -C "$repo_root" -czf "$archive_path" Libraries/vlc/vlc/win64-uwp/vlc-3.0.22-rc1
