#!/usr/bin/env bash
# Requiere uv y poppler-utils.
set -euo pipefail
cd "$(dirname "$0")/.."
export MD2PDF_SILENCIO=1 MD2PDF_HOME="$PWD" PATH="$PWD/bin:$PATH"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir "$t/tmp"
largo=$(for i in $(seq 1 60); do printf 'Parrafo %s con bastante texto para que la pagina se llene de a poco y haga falta mas de una.\n\n' "$i"; done)
printf '# Titulo\n\n## Seccion\n\nTexto de prueba con **negrita**.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```python ejemplo.py\nprint("hola")\n```\n\n%s\n' "$largo" > "$t/doc.md"

falla() { echo "FALLA: $1"; exit 1; }
hoja() { pdfinfo "$1" | awk '/Page size/ {print $3 "x" $5}'; }

for m in simple:doc.pdf doble:doc-doble.pdf paginado:doc-paginado.pdf; do
  TMPDIR="$t/tmp" md2pdf "${m%%:*}" "$t/doc.md" >/dev/null
  [[ -s "$t/${m##*:}" ]] || falla "cada modo deja su PDF junto al .md (falta ${m##*:})"
done

[[ -z $(ls -A "$t/tmp" | grep -v "^uv-") ]] || falla "no quedan archivos temporales de la conversion"
[[ $(hoja "$t/doc.pdf") == 595*x841* ]] || falla "el PDF simple es una hoja A4 vertical"
[[ $(hoja "$t/doc-paginado.pdf") == 842*x595* ]] || falla "el PDF paginado es una hoja A4 apaisada con dos paginas por cara"
paginas() { pdfinfo "$1" | awk '/^Pages/ {print $2}'; }
(( $(paginas "$t/doc-doble.pdf") != $(paginas "$t/doc.pdf") )) || falla "el PDF doble se compone distinto del simple"

echo x > "$t/a.txt"
md2pdf simple "$t/a.txt" 2>/dev/null && falla "un archivo que no es .md se rechaza"

j="$t/tree.json"; md2pdf-menu "$j" >/dev/null; md2pdf-menu "$j" >/dev/null
python3 - "$j" <<'PY' || falla "el submenu PDF queda una sola vez con sus tres opciones"
import json,sys
d=json.load(open(sys.argv[1]))["toplevel"]
assert len(d)==1 and len(d[0]["children"])==3, d
PY
echo OK
