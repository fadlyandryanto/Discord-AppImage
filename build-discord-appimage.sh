#!/bin/bash
set -e

APP="Discord"
ARCH="x86_64"
APPDIR="${APP}.AppDir"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -O appimagetool
chmod +x appimagetool

wget -q "https://discord.com/api/download?platform=linux&format=deb" -O discord.deb

dpkg-deb -x discord.deb extract_dir
mv extract_dir/usr/share/discord ./"$APPDIR"

cat <<'EOF' > ./"$APPDIR"/AppRun
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/Discord" "$@"
EOF
chmod +x ./"$APPDIR"/AppRun

cp extract_dir/usr/share/pixmaps/discord.png ./"$APPDIR"/discord.png
cp extract_dir/usr/share/applications/discord.desktop ./"$APPDIR"/discord.desktop
sed -i 's|Exec=/usr/share/discord/Discord|Exec=AppRun|g' ./"$APPDIR"/discord.desktop
sed -i 's|Exec=/usr/bin/discord|Exec=AppRun|g' ./"$APPDIR"/discord.desktop

VERSION=$(dpkg-deb -f discord.deb Version)
APPIMAGE_NAME="$APP-$VERSION-$ARCH.AppImage"

ARCH=x86_64 ./appimagetool \
  --comp zstd \
  --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 \
  ./"$APPDIR" \
  "$APPIMAGE_NAME"

mv "$APPIMAGE_NAME" "$OLDPWD"

echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "appimage_name=$APPIMAGE_NAME" >> "$GITHUB_OUTPUT"
