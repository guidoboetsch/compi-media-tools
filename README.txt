Compi media tools - third-party source and build materials

This repository provides the independent media tools used by Compi for
Windows, their corresponding sources, license notices and build recipe.
The media projects are authored by their respective upstream developers.

The prepared release contains:
- compi-media-tools-9.0.2-windows-x64.zip: standalone FFmpeg/FFprobe tools,
  licenses and recorded configuration.
- compi-media-tools-9.0.2-corresponding-source.zip: complete pinned sources
  for FFmpeg 9.0.2, x264 0.165.3223, LAME 3.100, zimg 3.0.6, dav1d 1.5.4
  and zlib 1.3.2, plus build scripts and toolchain package versions.
- ImageMagick-7.1.2-32-Windows.7z: verified upstream Windows source and
  build-material archive, including component dependency source trees.
- SHA256SUMS.txt: integrity checksums for the release archives.

FFmpeg tools use GPL v3. Individual component notices and licenses are
included in the archives. The MinGW and GCC runtime notices are included.
The build recipe contributed by Gran Berta is GPL-3.0-or-later.
ImageMagick and its dependencies retain their own licenses and notices.

To modify and rebuild FFmpeg tools, extract the corresponding-source ZIP
and follow BUILDING.txt. This was verified on Ubuntu 24.04 using the
supplied media-project source trees without downloading them again.
The prerequisites are standard Ubuntu compiler/build packages.

ImageMagick's original source archive and build instructions:
https://github.com/ImageMagick/ImageMagick/releases/tag/7.1.2-32
https://github.com/ImageMagick/Windows
Verified source revision: ad98b244c995d2e3051757fa3b7855f45b550d24.
Configure with Visual Studio C++/ATL/MFC, x64 Q8 static non-HDRI, to match
the unmodified photo-reader distribution used in Compi.

This material is separate from the Compi installer. Users only need these
source archives when studying, modifying or rebuilding the media tools.