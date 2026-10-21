#!/usr/bin/env bash
# T-14: nó com o plugin consultando um contrato que responde com saída MALFORMADA.
#
# Especificação (EEA PERM-240): o nó só aceita uma transação se transactionAllowed RETORNAR true, ou
# seja, um bool ABI (32 bytes, valor 1). Qualquer outra saída deve ser recusada (fail-close).
# Defeito do v1.0.0-rc.1 (${ISSUE_PLUGIN_SAIDA_MALFORMADA}): qualquer saída diferente de zero conta
# como permissão.
# Como o teste provoca a saída malformada: um contrato mínimo que responde a QUALQUER chamada com o
# próprio endereço numa palavra de 32 bytes. Configurado como Ingress de contas do nó, ele responde
# a getContractAddress com o próprio endereço (o plugin o toma como AccountRules) e a
# transactionAllowed com essa mesma palavra: diferente de zero, mas não é um bool ABI.
# Uma conta CADASTRADA e uma conta NÃO cadastrada enviam transação pelo nó: as duas devem ser
# recusadas. No fim, a configuração é restaurada e o nó se recupera.

fase "Teste T-14: nó com plugin e Ingress de contas que responde com saída malformada"
ESTADO_ATUAL="E12"
SN="$TRAB/start-network"
source "$RAIZ/lib/contas-teste.env"
PORTA_NOVO=${PORTA_NOVO:-20004}
REF_ISSUE="${ISSUE_PLUGIN_SAIDA_MALFORMADA:-saída malformada de transactionAllowed}"
dc_t14() { docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.t14.yml "$@"; }

# Contrato mínimo. Código de execução (9 bytes): ADDRESS PUSH1 0 MSTORE PUSH1 0x20 PUSH1 0 RETURN.
# Código de criação: copia esses 9 bytes para a memória e os devolve como código do contrato.
RUNTIME_MALFORMADO=0x3060005260206000f3
CRIACAO_MALFORMADO=0x600980600b6000396000f3${RUNTIME_MALFORMADO#0x}

passo "Garantir o nó 'novo' (plugin) com a configuração correta, acompanhando a cadeia"
em "$SN" executar "subir nó novo com a configuração correta" docker compose up -d novo
esperar_ate "RPC do nó novo" 120 responde "$PORTA_NOVO" || true
esperar_ate "nó novo acompanhar a cadeia" 300 acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO" || true

passo "Implantar o contrato de saída malformada (conta admin, pelo writer)"
R=$(node "$RAIZ/ferramentas/implantar.js" "http://127.0.0.1:${PORTA_WRITER}" "$CONTA_ADMIN_CHAVE" "$CRIACAO_MALFORMADO")
echo "$R" >> "$EXEC_DIR/transacoes.jsonl"
END_MALFORMADO=$(jq -r '.endereco // empty' <<<"$R")
fato t14.contrato_malformado "${END_MALFORMADO:-?}"
CODIGO=$(rpc "$PORTA_WRITER" eth_getCode "[\"${END_MALFORMADO:-0x0}\",\"latest\"]" | jq -r '.result // empty')
verificar T-14a "contrato de saída malformada implantado com o código esperado" "$RUNTIME_MALFORMADO" "${CODIGO:-?}" "$R"
SAIDA=$(rpc "$PORTA_WRITER" eth_call "[{\"to\":\"${END_MALFORMADO:-0x0}\",\"data\":\"0xe8b6d3c7\"},\"latest\"]" | jq -r '.result // empty')
ESPERADA="0x000000000000000000000000$(minusculo "${END_MALFORMADO#0x}")"
verificar T-14b "o contrato responde a qualquer chamada com o próprio endereço em 32 bytes (≠ 0, mas não é bool ABI)" \
  "$ESPERADA" "$(minusculo "${SAIDA:-?}")"
esperar_ate "nó novo importar o bloco do contrato" 120 acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO" || true

passo "Reconfigurar o nó 'novo' com o contrato de saída malformada como Ingress de contas"
cat > "$SN/docker-compose.t14.yml" <<EOF
services:
  novo:
    environment:
      BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS: "${END_MALFORMADO:-0x0}"
EOF
cp "$SN/docker-compose.t14.yml" "$EXEC_DIR/docker-compose.t14.yml"
sed 's/^/    │ /' "$SN/docker-compose.t14.yml"
em "$SN" executar "parar nó novo" docker compose stop novo
em "$SN" executar "subir nó novo com o Ingress de contas malformado" dc_t14 up -d novo
estado E13 "nó 'novo' (plugin) com BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS apontando para o contrato de saída malformada"
ESTADO_ATUAL="E13"
esperar_ate "RPC do nó novo" 120 responde "$PORTA_NOVO" || true
esperar_ate "nó novo acompanhar a cadeia (blocos sem transação)" 180 acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO" || true

passo "Conta CADASTRADA envia transação pelo nó"
R=$(node "$RAIZ/ferramentas/tx.js" "http://127.0.0.1:${PORTA_NOVO}" "$CONTA_ADMIN_CHAVE")
echo "$R" >> "$EXEC_DIR/transacoes.jsonl"
verificar T-14c "saída malformada não conta como permissão: transação de conta CADASTRADA é recusada" \
  "RECUSADA: -32007 Sender account not authorized to send transactions" \
  "$(jq -r .resumo <<<"$R")" "$R"

passo "Conta NÃO cadastrada envia transação pelo nó"
R=$(node "$RAIZ/ferramentas/tx.js" "http://127.0.0.1:${PORTA_NOVO}" aleatoria)
echo "$R" >> "$EXEC_DIR/transacoes.jsonl"
verificar T-14d "saída malformada não conta como permissão: transação de conta NÃO cadastrada é recusada" \
  "RECUSADA: -32007 Sender account not authorized to send transactions" \
  "$(jq -r .resumo <<<"$R")" "$R"

CONSOLE=$(cd "$SN" && docker compose logs --since 5m novo 2>/dev/null)
info "linhas do plugin no console do nó novo:"
grep -E "Unexpected output|Denying|AccountRules" <<<"$CONSOLE" | head -6 | cut -c1-240 | sed 's/^/    │ /'
verificar_que T-14e "plugin registra a saída malformada como ERROR, com a saída bruta" \
  "≥ 1 linha 'Unexpected output from … Denying.'" \
  "$(grep -c 'Unexpected output from .*Denying' <<<"$CONSOLE" || true) linha(s)" \
  test "$(grep -c 'Unexpected output from .*Denying' <<<"$CONSOLE" || true)" -ge 1

passo "Restaurar a configuração correta e verificar a recuperação"
mkdir -p "$EXEC_DIR/nos"; ( cd "$SN" && docker compose logs --timestamps novo > "$EXEC_DIR/nos/novo-console-t14.log" 2>&1 )
em "$SN" executar "parar nó novo" docker compose stop novo
em "$SN" executar "subir nó novo com a configuração correta" docker compose up -d novo
estado E14 "E13 restaurado: nó 'novo' (plugin) de volta à configuração correta"
ESTADO_ATUAL="E14"
esperar_ate "RPC do nó novo" 120 responde "$PORTA_NOVO" || true
esperar_ate "nó novo acompanhar a cadeia" 240 acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO" || true
R=$(node "$RAIZ/ferramentas/tx.js" "http://127.0.0.1:${PORTA_NOVO}" "$CONTA_ADMIN_CHAVE")
echo "$R" >> "$EXEC_DIR/transacoes.jsonl"
verificar T-14f "com a configuração corrigida, transação de conta cadastrada pelo nó volta a ser minerada" \
  "MINERADA, status 1" "$(jq -r .resumo <<<"$R")" "$R"
