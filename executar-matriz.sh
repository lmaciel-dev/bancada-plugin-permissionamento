#!/usr/bin/env bash
# Executa a bancada uma vez para cada versão do Besu da matriz (versoes.env), em sequência, e
# consolida os resultados em execucoes/matriz-<data-hora>/resumo.md. No GitHub, o workflow faz o
# mesmo com um job por versão, em paralelo.
#
# Uso: ./executar-matriz.sh
#   BESU_VERSOES="26.10.0" ./executar-matriz.sh    só as versões indicadas (da matriz)
#   TESTES="T04 T05" ./executar-matriz.sh                 filtro de testes, repassado a cada execução
#
# Código de saída: 0 = todas as versões passaram; 1 = alguma falhou; 2 = alguma abortou.

set -u
RAIZ="$(cd "$(dirname "$0")" && pwd)"
VERSOES=$(jq -r '.[]' <<<"$("$RAIZ/lib/matriz-besu.sh" json "${BESU_VERSOES:-}")") || exit 2
MATRIZ_DIR="$RAIZ/execucoes/matriz-$(date -u '+%Y%m%d-%H%M%S')"
mkdir -p "$MATRIZ_DIR"

EXECS=()
for v in $VERSOES; do
  antes=$(ls "$RAIZ/execucoes")
  echo; echo "████ Matriz: Besu $v ████"
  BESU_VERSAO_PLUGIN="$v" "$RAIZ/executar.sh"
  nova=$(comm -13 <(echo "$antes") <(ls "$RAIZ/execucoes") | grep -v '^matriz-' | head -1)
  [ -n "$nova" ] && EXECS+=("$RAIZ/execucoes/$nova") && echo "$v execucoes/$nova" >> "$MATRIZ_DIR/execucoes.txt"
done

[ "${#EXECS[@]}" -gt 0 ] || { echo "nenhuma execução gerada" >&2; exit 2; }
VERSOES_ESPERADAS="$VERSOES" bash "$RAIZ/lib/consolidar.sh" "${EXECS[@]}" > "$MATRIZ_DIR/resumo.md"
rc=$?
echo
echo "════════════════════════════════════════════════════════════════════"
grep '^| \*\*' "$MATRIZ_DIR/resumo.md" | sed 's/^/  /'
echo "  relatório consolidado: execucoes/$(basename "$MATRIZ_DIR")/resumo.md"
echo "════════════════════════════════════════════════════════════════════"
exit "$rc"
