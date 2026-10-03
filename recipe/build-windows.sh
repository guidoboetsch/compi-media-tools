#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
recipe="$(cd "$(dirname "$0")" && pwd)"
root="${COMPI_MEDIA_WORK:-$PWD/media-work}"
mkdir -p "$root"; root="$(cd "$root" && pwd)"
prefix="$root/stage"
mkdir -p "$root/src" "$root/downloads" "$prefix" "$root/out"
export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-static -static-libgcc -static-libstdc++"
export GIT_CEILING_DIRECTORIES="$root/src"
jobs="${COMPI_MEDIA_JOBS:-$(nproc)}"
python3 - "$recipe/sources.json" "$root" <<'PY'
import hashlib,json,os,pathlib,subprocess,sys,tarfile,urllib.request
manifest=json.load(open(sys.argv[1])); root=pathlib.Path(sys.argv[2])
for name, item in manifest.items():
    target=root/'src'/name
    if os.environ.get('COMPI_MEDIA_OFFLINE')=='1':
        if not target.is_dir(): raise RuntimeError('Missing supplied source: '+name)
        continue
    if 'git' in item:
        if not target.exists():
            subprocess.run(['git','clone',item['git'],str(target)],check=True)
        subprocess.run(['git','-C',str(target),'checkout','--detach',item['commit']],check=True)
        actual=subprocess.check_output(['git','-C',str(target),'rev-parse','HEAD'],text=True).strip()
        if actual!=item['commit']: raise RuntimeError('Unexpected source revision: '+name)
    else:
        archive=root/'downloads'/(name+'.tar.gz')
        if not archive.exists(): urllib.request.urlretrieve(item['url'],archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest()!=item['sha256']: raise RuntimeError('Source checksum mismatch: '+name)
        if not target.exists():
            target.mkdir()
            with tarfile.open(archive) as t:
                for m in t.getmembers():
                    parts=pathlib.PurePosixPath(m.name).parts
                    if len(parts)<2: continue
                    m.name=str(pathlib.PurePosixPath(*parts[1:]))
                    t.extract(m,target,filter='data')
PY

cd "$root/src/x264"
./configure --host=x86_64-w64-mingw32 --cross-prefix=x86_64-w64-mingw32- --prefix="$prefix" --enable-static --disable-cli --disable-opencl
make -j"$jobs"; make install

cd "$root/src/lame"
./configure --host=x86_64-w64-mingw32 --prefix="$prefix" --disable-shared --enable-static --disable-frontend --disable-decoder
make -j"$jobs"; make install

cd "$root/src/zimg"
./autogen.sh
./configure --host=x86_64-w64-mingw32 --prefix="$prefix" --disable-shared --enable-static
make -j"$jobs"; make install

cd "$root/src/zlib"
CC=x86_64-w64-mingw32-gcc AR=x86_64-w64-mingw32-ar RANLIB=x86_64-w64-mingw32-ranlib CHOST=x86_64-w64-mingw32 ./configure --prefix="$prefix" --static
make -j"$jobs"; make install

cat > "$root/cross.ini" <<'INI'
[binaries]
c = 'x86_64-w64-mingw32-gcc'
cpp = 'x86_64-w64-mingw32-g++'
ar = 'x86_64-w64-mingw32-ar'
strip = 'x86_64-w64-mingw32-strip'
windres = 'x86_64-w64-mingw32-windres'
pkg-config = 'pkg-config'
[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
[properties]
needs_exe_wrapper = true
INI
cd "$root/src/dav1d"
meson setup "$root/dav1d-build" --cross-file "$root/cross.ini" --prefix "$prefix" --default-library static --buildtype release -Denable_tools=false -Denable_tests=false -Denable_examples=false -Denable_docs=false
meson compile -C "$root/dav1d-build" -j "$jobs"
meson install -C "$root/dav1d-build"

cd "$root/src/ffmpeg"
./configure --prefix="$prefix" --target-os=mingw32 --arch=x86_64 --cross-prefix=x86_64-w64-mingw32- --enable-cross-compile \
  --enable-gpl --enable-version3 --enable-libx264 --enable-libmp3lame --enable-libzimg --enable-libdav1d --enable-zlib \
  --disable-shared --enable-static --disable-autodetect --disable-debug --disable-doc --disable-ffplay \
  --disable-network --pkg-config=pkg-config --pkg-config-flags=--static --extra-cflags="-I$prefix/include" --extra-ldflags="-L$prefix/lib $LDFLAGS"
make -j"$jobs" ffmpeg.exe ffprobe.exe

bundle="$root/out/compi-media-tools-9.0.2-windows-x64"
mkdir -p "$bundle/licenses" "$bundle/provenance" "$root/out/corresponding-source"
cp ffmpeg.exe ffprobe.exe "$bundle/"
cp COPYING.GPLv3 "$bundle/LICENSE"
cp config.h ffbuild/config.mak ffbuild/config.log "$bundle/provenance/"
cp "$recipe/sources.json" "$bundle/provenance/"
for lib in x264 lame zimg dav1d zlib; do
  mkdir -p "$bundle/licenses/$lib"
  find "$root/src/$lib" -maxdepth 1 -type f \( -iname 'copying*' -o -iname 'license*' -o -iname 'copyright*' \) -exec cp {} "$bundle/licenses/$lib/" \;
done
cp /usr/share/doc/mingw-w64/copyright "$bundle/licenses/mingw-w64-copyright.txt"
cp "$recipe/GCC-RUNTIME-LIBRARY-EXCEPTION.txt" "$recipe/GCC-RUNTIME-NOTICE.txt" "$bundle/licenses/"
dpkg-query -W > "$bundle/provenance/toolchain-packages.txt"
for exe in "$bundle/ffmpeg.exe" "$bundle/ffprobe.exe"; do
  x86_64-w64-mingw32-objdump -p "$exe" | sed -n 's/.*DLL Name: //p' > "$exe.dll-imports.txt"
  if grep -Eiq 'libgcc|libstdc|libwinpthread|libx264|libmp3lame|libdav1d|libzimg' "$exe.dll-imports.txt"; then
    echo "Non-system DLL dependency in $exe" >&2; exit 1
  fi
done
cat > "$bundle/README.txt" <<'TXT'
Compi media tools - Windows x64 - FFmpeg 9.0.2
Copyright (c) 2000-2026 the FFmpeg developers.
License: GPL v3. See LICENSE and licenses/ for external library notices.
Includes x264 0.165.3223, LAME 3.100, zimg 3.0.6, dav1d 1.5.4 and zlib 1.3.2.
These are standalone executables. Compi calls them as separate processes.
The corresponding-source archive is distributed alongside this binary archive:
compi-media-tools-9.0.2-corresponding-source.zip
It contains pinned upstream sources, licenses, generated configuration,
the build recipe and recorded toolchain versions. Build on Ubuntu 24.04
with the prerequisites described in BUILDING.txt and build-windows.sh.
ImageMagick is a separate distribution with its own source archive.
TXT

# Copy full sources, configure files and build scripts; omit build objects and git caches.
source_bundle="$root/out/corresponding-source"
for lib in ffmpeg x264 lame zimg dav1d zlib; do
  mkdir -p "$source_bundle/src/$lib"
  rsync -a --exclude=.git/logs --exclude=.git/hooks --exclude='*.o' --exclude='*.a' --exclude='*.exe' --exclude='*.dll' --exclude='*.lo' --exclude='*.la' --exclude=ffbuild/bin2c --exclude=.deps --exclude=.libs "$root/src/$lib/" "$source_bundle/src/$lib/"
done
cp -R "$recipe/" "$source_bundle/recipe"
cp "$root/cross.ini" "$source_bundle/"
cp -R "$bundle/provenance/" "$source_bundle/provenance"
cp "$recipe/BUILDING.txt" "$source_bundle/"
cd "$root/out"
zip -qr compi-media-tools-9.0.2-windows-x64.zip "$(basename "$bundle")"
zip -qr compi-media-tools-9.0.2-corresponding-source.zip corresponding-source
sha256sum *.zip > SHA256SUMS.txt
