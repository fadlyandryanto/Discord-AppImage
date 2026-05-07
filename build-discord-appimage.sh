#!/bin/bash
set -e

APP="Discord"
ARCH="x86_64"
APPDIR="${APP}.AppDir"

WORKDIR=$(mktemp -d)
trap 'echo "--> Cleaning up temporary directory..."; rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "✅ Downloading necessary files..."
wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -O appimagetool
chmod +x appimagetool

echo "Downloading Discord..."
wget -q "https://discord.com/api/download?platform=linux&format=deb" -O discord.deb

echo "📦 Extracting package..."
# dpkg-deb preserves the exact directory structure (usr/bin and usr/share)
dpkg-deb -x discord.deb "$APPDIR"

echo "🧹 Cleaning up and patching for AppImage..."
# Remove postinst script as it requires root and is useless for AppImages
rm -f "$APPDIR/usr/share/discord/postinst.sh"

# Patch the wrapper script so it finds the bootstrap relative to the AppImage mount
sed -i 's|bootstrap=/usr/share/$BOOTSTRAP_SUFFIX|bootstrap=${APPDIR}/usr/share/$BOOTSTRAP_SUFFIX|g' "$APPDIR/usr/bin/discord"
sed -i 's|bootstrap=/opt/$BOOTSTRAP_SUFFIX|bootstrap=${APPDIR}/opt/$BOOTSTRAP_SUFFIX|g' "$APPDIR/usr/bin/discord"

echo "🎨 Setting up icons and desktop entry..."
# AppImage spec requires the desktop file and icon to be at the root of the AppDir
cp "$APPDIR/usr/share/discord/discord.desktop" "$APPDIR/"
cp "$APPDIR/usr/share/discord/discord.png" "$APPDIR/"

# Fix the Exec line in the desktop file
sed -i 's|^Exec=.*|Exec=discord|' "$APPDIR/discord.desktop"

echo "🚀 Creating the AppRun entrypoint..."
# $APPDIR is automatically set by the AppImage runtime.
# We inject our internal bin folder into the PATH so it executes the patched wrapper.
cat <<'EOF' > "$APPDIR/AppRun"
#!/bin/sh
export PATH="${APPDIR}/usr/bin:${PATH}"
exec "${APPDIR}/usr/bin/discord" "$@"
EOF
chmod +x "$APPDIR/AppRun"

echo "🔎 Determining application version..."
VERSION=$(dpkg-deb -f discord.deb Version)
APPIMAGE_NAME="$APP-$VERSION-$ARCH.AppImage"

echo "Building $APPIMAGE_NAME..."
ARCH=x86_64 ./appimagetool \
    --comp zstd \
    --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 \
    "$APPDIR" \
    "$APPIMAGE_NAME"

echo "🎉 Build complete!"
mv "$APPIMAGE_NAME" "$OLDPWD"
echo "AppImage created at: $(realpath "$OLDPWD/$APPIMAGE_NAME")"

# Export variables to GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "version=$VERSION" >> "$GITHUB_OUTPUT"
    echo "appimage_name=$APPIMAGE_NAME" >> "$GITHUB_OUTPUT"
fi
