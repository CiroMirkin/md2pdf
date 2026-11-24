#!/usr/bin/env bash
# Uso: ./build-deb.sh [version]  ->  dist/md2pdf_<version>_all.deb
set -euo pipefail
cd "$(dirname "$0")"
V="${1:-0.1.0}"
B=build/md2pdf_${V}_all
rm -rf build && mkdir -p "$B"/{DEBIAN,usr/bin,usr/lib/md2pdf/src,usr/share/nemo/actions,usr/share/keyrings,etc/apt/sources.list.d} dist
cp bin/* "$B/usr/bin/"
cp src/md2pdf/*.py "$B/usr/lib/md2pdf/src/"
cp nemo/*.nemo_action "$B/usr/share/nemo/actions/"
# La clave publica la genera el workflow de release y sin ella el paquete se instala pero no se actualiza por apt
[[ -f build-keyring/md2pdf.gpg ]] && cp build-keyring/md2pdf.gpg "$B/usr/share/keyrings/" && cp packaging/apt/md2pdf.list "$B/etc/apt/sources.list.d/"
sed "s/@VERSION@/$V/" packaging/control > "$B/DEBIAN/control"
cp packaging/postinst "$B/DEBIAN/"
fakeroot dpkg-deb --build "$B" "dist/md2pdf_${V}_all.deb"
