#!/usr/bin/env bash
# Uso: ./build-deb.sh [version]  ->  dist/md2pdf_<version>_all.deb
set -euo pipefail
cd "$(dirname "$0")"
V="${1:-0.1.0}"
B=build/md2pdf_${V}_all
rm -rf build && mkdir -p "$B"/{DEBIAN,usr/bin,usr/lib/md2pdf/src,usr/share/nemo/actions} dist
cp bin/* "$B/usr/bin/"
cp src/md2pdf/*.py "$B/usr/lib/md2pdf/src/"
cp nemo/*.nemo_action "$B/usr/share/nemo/actions/"
sed "s/@VERSION@/$V/" packaging/control > "$B/DEBIAN/control"
cp packaging/postinst "$B/DEBIAN/"
fakeroot dpkg-deb --build "$B" "dist/md2pdf_${V}_all.deb"
