#!/usr/bin/env bash
# Recompila linux-cachyos con el parche del teclado interno (AIR SRL CX307XX).
# Uso: ./build.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HOME/linux-cachyos"

echo "==> Instalando dependencias de compilación"
sudo pacman -S --needed base-devel git bc rust rust-bindgen rust-src pacman-contrib

echo "==> Obteniendo el PKGBUILD de CachyOS"
if [ -d "$WORK/.git" ]; then
    git -C "$WORK" pull --ff-only
else
    git clone https://github.com/CachyOS/linux-cachyos.git "$WORK"
fi
cd "$WORK/linux-cachyos"

echo "==> Agregando el parche al PKGBUILD"
cp "$HERE/air-cx307xx.patch" .
if ! grep -q 'air-cx307xx.patch' PKGBUILD; then
    # Se inserta justo antes de validpgpkeys, o sea después del array source=()
    sed -i '/^validpgpkeys=(/i source+=("air-cx307xx.patch")' PKGBUILD
fi
grep -n 'air-cx307xx' PKGBUILD
updpkgsums

echo "==> Compilando (puede tardar varias horas; dejá la notebook enchufada)"
systemd-inhibit --what=sleep:idle --why="compilando kernel" \
    makepkg -Cs --skippgpcheck

echo
echo "==> Listo. Instalá con:"
echo "    cd $WORK/linux-cachyos"
echo "    sudo pacman -U linux-cachyos-*-x86_64.pkg.tar.zst linux-cachyos-headers-*-x86_64.pkg.tar.zst"
