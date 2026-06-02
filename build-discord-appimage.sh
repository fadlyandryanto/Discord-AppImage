#!/bin/bash
set -e

APP="Discord"
ARCH="x86_64"
APPDIR="${APP}.AppDir"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

wget -q "https://github.com/pkgforge-dev/appimagetool/releases/latest/download/appimagetool-x86_64-linux" -O appimagetool
chmod +x appimagetool

wget -q "https://discord.com/api/download?platform=linux&format=deb" -O discord.deb

dpkg-deb -x discord.deb extract_dir
mkdir -p ./"$APPDIR"
mv extract_dir/usr ./"$APPDIR"/

cp ./"$APPDIR"/usr/share/discord/discord.desktop ./"$APPDIR"/
cp ./"$APPDIR"/usr/share/discord/discord.png ./"$APPDIR"/
cp ./"$APPDIR"/discord.png ./"$APPDIR"/.DirIcon

cat <<'EOF' > ./"$APPDIR"/AppRun
#!/bin/sh
export APPDIR="$(dirname "$(readlink -f "${0}")")"

CHANNEL=stable
DOWNLOAD=https://updates.discord.com/
DIR=discord
EXE=Discord
BOOTSTRAP="$APPDIR/usr/share/discord/updater_bootstrap"

config_home=$XDG_CONFIG_HOME
if [ -z "$config_home" ]; then
    config_home=$HOME/.config
fi

discord_host=$config_home/$DIR/$EXE

if [ ! -x "$discord_host" ]; then
    mkdir -p "$config_home/$DIR"
    if [ ! -d "$config_home/$DIR" ]; then
        echo "Fatal error, failed to create $DIR in $config_home" >&2
        exit 1
    fi
    
    if [ -t 1 ]; then
        zenity=--no-zenity
    else
        zenity=--zenity
    fi
    
    app_dir=$("$BOOTSTRAP" $zenity "$config_home/$DIR" $CHANNEL "$DOWNLOAD")

    if [ $? -eq 0 ] ; then
        echo "Bootstrap complete"
        exec "$config_home/$DIR/$app_dir/$EXE" "$@"
    else
        echo "Bootstrap failed or was canceled"
        exit 2
    fi
fi
exec "$discord_host" "$@"
EOF
chmod +x ./"$APPDIR"/AppRun

sed -i 's|^Exec=.*|Exec=AppRun %U|g' ./"$APPDIR"/discord.desktop

VERSION=$(dpkg-deb -f discord.deb Version)
APPIMAGE_NAME="$APP-$VERSION-$ARCH.AppImage"

export OPTIMIZE_LAUNCH=1 
export OUTNAME="$APPIMAGE_NAME"

./appimagetool ./"$APPDIR" -o ./dist

mv ./dist/"$APPIMAGE_NAME" "$OLDPWD"

echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "appimage_name=$APPIMAGE_NAME" >> "$GITHUB_OUTPUT"
