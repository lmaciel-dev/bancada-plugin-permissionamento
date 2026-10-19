#!/usr/bin/env bash
# Consolida, num relatório único (Markdown), execuções da bancada em versões diferentes do Besu
# (matriz de versoes.env). Lê só fatos.jsonl e verificacoes.jsonl de cada execução.
# Uso: consolidar.sh <diretório>...   (procura as execuções em qualquer nível abaixo de cada um)
#   VERSOES_ESPERADAS="25.12.0 26.10.0" consolidar.sh ...   acusa versão esperada sem execução
# Código de saída: 0 = todas as versões passaram; 1 = alguma falhou; 2 = alguma abortou ou faltou.
set -u
fatov() { jq -r --arg k "$2" 'select(.tipo=="fato" and .chave==$k) | .valor' "$1/fatos.jsonl" | tail -1; }

EXECS=$(find "$@" -name verificacoes.jsonl -printf '%h\n' | while read -r d; do
  echo "$(fatov "$d" besu.versao_plugin) $d"; done | sort -V)
[ -n "$EXECS" ] || { echo "**❌ Nenhuma execução encontrada em \`$*\`.**"; exit 2; }

rc=0
echo "# Bancada do plugin de permissionamento: matriz de versões do Besu"
echo
echo "Cada linha é uma execução completa da bancada com os nós migrados para o plugin naquela versão do Besu."
echo "Os nós da fase inicial seguem no Besu $(fatov "$(echo "$EXECS" | head -1 | cut -d' ' -f2-)" imagem.besu_inicial | sed 's/@.*//; s/.*://') nativo em todas."
echo
echo "| Besu | Versão informada pelo nó | Resultado | Verificações | 🐞 | 🔎 | Execução |"
echo "|---|---|---|---|---|---|---|"
while read -r versao d; do
  V="$d/verificacoes.jsonl"
  total=$(jq -s '[.[] | select(.observacao != true)] | length' "$V")
  ok=$(jq -s '[.[] | select(.observacao != true and .ok)] | length' "$V")
  bugs=$(jq -s '[.[] | select((.defeito // "") != "" and .ok)] | length' "$V")
  obs=$(jq -s '[.[] | select(.observacao == true)] | length' "$V")
  aborto=$(jq -r 'select(.tipo=="aborto") | .motivo' "$d/fatos.jsonl" | head -1)
  if [ -n "$aborto" ]; then res="❌ abortada: $aborto"; rc=2
  elif [ "$ok" = "$total" ]; then res="✅ passou"
  else res="❌ $((total - ok)) falha(s)"; [ "$rc" -eq 0 ] && rc=1; fi
  echo "| **${versao:-?}** | \`$(fatov "$d" besu.versao_informada_plugin)\` | $res | $ok/$total | $bugs | $obs | \`$(basename "$d")\` |"
done <<<"$EXECS"
for v in ${VERSOES_ESPERADAS:-}; do
  awk -v v="$v" '$1 == v { achou = 1 } END { exit !achou }' <<<"$EXECS" && continue
  echo "| **$v** | — | ❌ sem resultado (a execução não gerou evidências) | — | — | — | — |"; rc=2
done
echo
echo "🐞 = defeitos conhecidos reproduzidos de propósito; 🔎 = observações (não contam como falha). Ver o relatório de cada execução."
echo

# Mesma verificação com veredito diferente entre versões: é aqui que aparece o que depende do Besu.
DIVERG=$(while read -r versao d; do
  jq -c --arg v "$versao" '{v:$v, id, descricao, ok, obtido}' "$d/verificacoes.jsonl"; done <<<"$EXECS" \
  | jq -rs 'group_by(.id) | map(select((map(.ok) | unique | length) > 1))
      | .[] | "| \(.[0].id) | \(.[0].descricao | gsub("\\|"; "¦")) | \(map("\(if .ok then "✅" else "❌" end) \(.v): `\(.obtido | tostring | gsub("\\|"; "¦"))`") | join("<br>")) |"')
echo "## Verificações com resultado diferente entre versões"
echo
if [ -n "$DIVERG" ]; then
  echo "| ID | Verificação | Resultado por versão |"
  echo "|---|---|---|"
  echo "$DIVERG"
else
  echo "Nenhuma: todas as verificações tiveram o mesmo veredito em todas as versões."
fi
echo
FALHAS=$(while read -r versao d; do
  jq -r --arg v "$versao" 'select(.ok | not) | select(.observacao != true) | "| \($v) | \(.id) | \(.descricao | gsub("\\|"; "¦")) | `\(.esperado | gsub("\\|"; "¦"))` | `\(.obtido | tostring | gsub("\\|"; "¦"))` |"' "$d/verificacoes.jsonl"
done <<<"$EXECS")
if [ -n "$FALHAS" ]; then
  echo "## Falhas por versão"
  echo
  echo "| Besu | ID | Verificação | Esperado | Obtido |"
  echo "|---|---|---|---|---|"
  echo "$FALHAS"
  echo
fi
exit "$rc"
