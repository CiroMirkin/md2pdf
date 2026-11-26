#!/usr/bin/env bash
# Requiere uv y poppler-utils.
set -euo pipefail
cd "$(dirname "$0")/.."
export MD2PDF_SILENCIO=1 MD2PDF_HOME="$PWD" PATH="$PWD/bin:$PATH"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir "$t/tmp"
largo=$(for i in $(seq 1 60); do printf 'Parrafo %s con bastante texto para que la pagina se llene de a poco y haga falta mas de una.\n\n' "$i"; done)
printf '# Titulo\n\n## Seccion\n\nTexto de prueba con **negrita**, ***ambas:*** y **negrita con *italica***.\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```python ejemplo.py\nprint("hola")\n```\n\n%s\n' "$largo" > "$t/doc.md"

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

# PNG de 1x1
base64 -d <<<'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhWMjWwAAAABJRU5ErkJggg==' > "$t/foto.png"
printf '# Titulo\n\n![](./foto.png)\n\nTexto.\n' > "$t/foto.md"
md2pdf simple "$t/foto.md" >/dev/null || falla "un .md con una imagen que no es SVG se convierte"
(( $(pdfimages -list "$t/foto.pdf" | tail -n +3 | wc -l) > 0 )) || falla "la imagen queda dentro del PDF"

printf '# Titulo\n\n_inclinada_ y **negrita con _ambas_**, nombre_de_variable, __init__, [_enlace_](https://x.org/_ruta_) y **_cruce** suelto_.\n' > "$t/guion.md"
md2pdf simple "$t/guion.md" >/dev/null || falla "un .md con guiones bajos se convierte"
texto=$(pdftotext "$t/guion.pdf" - | tr '\n' ' ')
[[ $texto == *"inclinada y negrita con ambas, nombre_de_variable, __init__, enlace"* ]] || falla "_texto_ es italica y no toca los guiones bajos dentro de una palabra ($texto)"
grep -aq 'https://x.org/_ruta_' "$t/guion.pdf" || falla "los guiones bajos de una URL quedan como estan"

printf '# Titulo\n\n[![Diagrama remoto](https://x.org/a.webp)](https://x.org/pagina)\n\n![Foto remota](https://x.org/b.png)\n\n[![](https://x.org/c.png)](https://x.org/sin-texto)\n\nVer ![insignia](https://x.org/d.svg) aca.\n\n[![](./foto.png)](https://x.org/local)\n' > "$t/enlace.md"
md2pdf simple "$t/enlace.md" >/dev/null || falla "un .md con imagenes remotas se convierte"
texto=$(pdftotext "$t/enlace.pdf" - | tr '\n' ' ')
[[ $texto == *"Diagrama remoto"*"Foto remota"*"imagen"*"Ver insignia aca."* && $texto != *']('* && $texto != *x.org* ]] || falla "de una imagen remota sale solo su texto ($texto)"
grep -aq 'https://x.org/pagina' "$t/enlace.pdf" && grep -aq 'https://x.org/b.png' "$t/enlace.pdf" || falla "ese texto enlaza al destino, o a la imagen si no hay otro"
(( $(pdfimages -list "$t/enlace.pdf" | tail -n +3 | wc -l) > 0 )) || falla "una imagen local con enlace se inserta"

echo x > "$t/a.txt"
md2pdf simple "$t/a.txt" 2>/dev/null && falla "un archivo que no es .md se rechaza"

j="$t/tree.json"; md2pdf-menu "$j" >/dev/null; md2pdf-menu "$j" >/dev/null
python3 - "$j" <<'PY' || falla "el submenu PDF queda una sola vez con sus tres opciones"
import json,sys
d=json.load(open(sys.argv[1]))["toplevel"]
assert len(d)==1 and len(d[0]["children"])==3, d
PY
echo OK
