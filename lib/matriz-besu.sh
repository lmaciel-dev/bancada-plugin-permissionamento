#!/usr/bin/env bash
# Matriz de versões do Besu dos nós com o plugin (BESU_MATRIZ_PLUGIN, em versoes.env).
#
# Como biblioteca (source, depois de versoes.env):
#   matriz_versoes                 lista as versões da matriz, uma por linha, na ordem do arquivo
#   matriz_resolver <versão>       define BESU_IMAGEM_PLUGIN, BESU_CLIENTE_PLUGIN e
#                                  BESU_OPCOES_MIGRACAO; falha se a versão não estiver na matriz
#   yaml_opcoes_migracao           bloco "environment:" de um serviço do compose com as opções de
#                                  migração da versão (nada, se não houver)
#
# Como comando (usado pelo workflow do GitHub para montar os jobs):
#   lib/matriz-besu.sh json ["<versão> <versão>..."]
#     imprime as versões pedidas (ou a matriz inteira) como lista JSON; código 1 se alguma
#     versão pedida não estiver na matriz

matriz_versoes() {
  awk 'NF { print $1 }' <<<"$BESU_MATRIZ_PLUGIN"
}

matriz_resolver() {
  local linha
  linha=$(awk -v v="$1" '$1 == v' <<<"$BESU_MATRIZ_PLUGIN")
  [ -n "$linha" ] || return 1
  BESU_IMAGEM_PLUGIN=$(awk '{ print $2 }' <<<"$linha")
  BESU_CLIENTE_PLUGIN=$(awk '{ print $3 }' <<<"$linha")
  BESU_OPCOES_MIGRACAO=$(awk '$4 != "-" { print $4 }' <<<"$linha")
}

yaml_opcoes_migracao() {
  [ -n "${BESU_OPCOES_MIGRACAO:-}" ] || return 0
  echo "    environment:"
  tr ',' '\n' <<<"$BESU_OPCOES_MIGRACAO" | while IFS='=' read -r var valor; do
    echo "      $var: \"$valor\""
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -eu
  source "$(cd "$(dirname "$0")/.." && pwd)/versoes.env"
  [ "${1:-}" = json ] || { echo "uso: $0 json [\"<versão> ...\"]" >&2; exit 2; }
  pedidas="${2:-}"
  [ -n "$(echo "$pedidas" | tr -d '[:space:]')" ] || pedidas=$(matriz_versoes)
  for v in $pedidas; do
    matriz_resolver "$v" || { echo "versão do Besu fora da matriz de versoes.env: $v (disponíveis: $(matriz_versoes | tr '\n' ' '))" >&2; exit 1; }
  done
  printf '%s\n' $pedidas | jq -R . | jq -cs .
fi
