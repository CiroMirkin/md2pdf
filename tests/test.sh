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

# Un servidor local hace de internet
mkdir "$t/web"; cp "$t/foto.png" "$t/web/foto"
echo '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="40"><text x="10" y="25">DentroDelSvg</text></svg>' > "$t/web/dibujo"
echo '<html>no soy una imagen</html>' > "$t/web/pagina.png"
echo '<svg xmlns="http://www.w3.org/2000/svg" width="200"' > "$t/web/cortado"
python3 -u -c 'import functools, http.server as h, sys
s = h.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(h.SimpleHTTPRequestHandler, directory=sys.argv[1]))
print(s.server_port); s.serve_forever()' "$t/web" > "$t/puerto" 2>/dev/null &
servidor=$!; trap 'kill $servidor; rm -rf "$t"' EXIT
until [[ -s "$t/puerto" ]]; do sleep 0.1; done
web="http://127.0.0.1:$(cat "$t/puerto")"
imagenes() { pdfimages -list "$1" | tail -n +3 | wc -l; }

# las URL no llevan extension: el tipo sale del contenido
printf '# Titulo\n\n[![Foto remota](%s/foto)](%s/destino)\n\n![](%s/dibujo)\n' "$web" "$web" "$web" > "$t/remota.md"
md2pdf simple "$t/remota.md" >/dev/null || falla "un .md con imagenes remotas se convierte"
(( $(imagenes "$t/remota.pdf") == 1 )) || falla "una foto remota se ve en el PDF"
[[ $(pdftotext "$t/remota.pdf" - | tr '\n' ' ') == *DentroDelSvg* ]] || falla "un SVG remoto se ve en el PDF"

printf '# Titulo\n\n[![No existe](%s/nada)](%s/destino)\n\n![Sin servidor](http://127.0.0.1:1/b.png)\n\n![](%s/pagina.png)\n\n![SVG cortado](%s/cortado)\n\nVer [![insignia](%s/foto)](%s/otro) y ![sello](%s/foto) aca.\n' "$web" "$web" "$web" "$web" "$web" "$web" "$web" > "$t/rota.md"
md2pdf simple "$t/rota.md" >/dev/null || falla "una imagen que no se puede traer no corta la conversion"
texto=$(pdftotext "$t/rota.pdf" - | tr '\n' ' ')
[[ $texto == *"No existe"*"Sin servidor"*"imagen"*"SVG cortado"*"Ver insignia y sello aca."* && $texto != *']('* ]] || falla "en lugar de esas imagenes y de las que van en medio del texto sale su texto ($texto)"
grep -aq "$web/destino" "$t/rota.pdf" && grep -aq 'http://127.0.0.1:1/b.png' "$t/rota.pdf" || falla "ese texto enlaza al destino, o a la imagen si no hay otro"
(( $(imagenes "$t/rota.pdf") == 0 )) || falla "una imagen en medio del texto no se inserta"

printf '# Titulo\n\n[![](./foto.png)](https://x.org/local)\n' > "$t/local.md"
md2pdf simple "$t/local.md" >/dev/null && (( $(imagenes "$t/local.pdf") == 1 )) || falla "una imagen local con enlace se inserta"

echo x > "$t/a.txt"
md2pdf simple "$t/a.txt" 2>/dev/null && falla "un archivo que no es .md se rechaza"

j="$t/tree.json"; md2pdf-menu "$j" >/dev/null; md2pdf-menu "$j" >/dev/null
python3 - "$j" <<'PY' || falla "el submenu PDF queda una sola vez con sus tres opciones"
import json,sys
d=json.load(open(sys.argv[1]))["toplevel"]
assert len(d)==1 and len(d[0]["children"])==3, d
PY
echo OK
