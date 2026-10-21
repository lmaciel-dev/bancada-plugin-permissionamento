#!/usr/bin/env bash
# T-13: nó com o plugin CORRIGIDO e configuração ERRADA (endereço do Ingress de contas ausente e,
# depois, igual ao endereço zero).
#
# Especificação (o que deveria acontecer): diante de configuração obrigatória ausente, o nó deve
# se recusar a subir, com erro claro — e não operar de forma degradada.
# Este teste usa um jar do plugin com a correção da issue de configuração ausente
# (${ISSUE_PLUGIN_CONFIG_AUSENTE}) e espera o comportamento CORRETO, ao contrário do T-10,
# que demonstra o defeito do ${PLUGIN_VERSAO} anterior.

fase "Teste T-13: nó com plugin corrigido e endereço do Ingress de contas ausente ou zero recusa-se a subir"
ESTADO_ATUAL="E4"
SN="$TRAB/start-network"
PORTA_NOVO=${PORTA_NOVO:-20004}
REF_CORRECAO="plugin ${PLUGIN_VERSAO}: configuração obrigatória ausente impede a subida${ISSUE_PLUGIN_CONFIG_AUSENTE:+ — $ISSUE_PLUGIN_CONFIG_AUSENTE}"
dc_t13() { docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.t13.yml "$@"; }

passo "Reconfigurar o nó 'novo' SEM o endereço do Ingress de contas (variável vazia)"
cat > "$SN/docker-compose.t13.yml" <<'EOF'
services:
  novo:
    environment:
      BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS: ""
EOF
cp "$SN/docker-compose.t13.yml" "$EXEC_DIR/docker-compose.t13.yml"
sed 's/^/    │ /' "$SN/docker-compose.t13.yml"
em "$SN" executar "parar nó novo" docker compose stop novo
B_ANTES=$(bloco_atual "$PORTA_VALIDATOR")
em "$SN" executar "subir nó novo com a configuração errada" dc_t13 up -d novo

passo "O nó deve SE RECUSAR a subir: RPC não responde e o Besu aborta"
sobe=não; esperar_ate "RPC do nó novo (não deve responder)" 60 responde "$PORTA_NOVO" && sobe=sim
CONSOLE=$(cd "$SN" && docker compose logs --since 3m novo 2>/dev/null)
info "linhas do plugin no console do nó novo:"
grep -E "invalid configuration|mandatory|Permissioning Plugin|Error registering plugin|RuntimeException" <<<"$CONSOLE" | head -6 | cut -c1-240 | sed 's/^/    │ /'
verificar T-13a "com configuração obrigatória ausente, o nó NÃO sobe (RPC não responde)" "não" "$sobe"
verificar_que T-13b "plugin reporta a configuração inválida com o nome da variável" \
  "≥ 1 linha 'invalid configuration — BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS is mandatory and is not set'" \
  "$(grep -c 'invalid configuration — BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS is mandatory and is not set' <<<"$CONSOLE" || true) linha(s)" \
  test "$(grep -c 'invalid configuration — BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS is mandatory and is not set' <<<"$CONSOLE" || true)" -ge 1
verificar_que T-13c "Besu aborta o registro do plugin (Error registering plugin)" \
  "≥ 1 linha 'Error registering plugin'" \
  "$(grep -c 'Error registering plugin' <<<"$CONSOLE" || true) linha(s)" \
  test "$(grep -c 'Error registering plugin' <<<"$CONSOLE" || true)" -ge 1

passo "A rede continua produzindo blocos apesar do nó mal configurado"
BN1=$(bloco_atual "$PORTA_VALIDATOR"); sleep 15; BN2=$(bloco_atual "$PORTA_VALIDATOR")
verificar_que T-13d "validator segue produzindo blocos" \
  "bloco avançou: $BN1 → $BN2" "$BN1 → $BN2" test "$BN2" -gt "$BN1"

passo "Reconfigurar o nó 'novo' com o endereço ZERO no Ingress de contas"
cat > "$SN/docker-compose.t13.yml" <<'EOF'
services:
  novo:
    environment:
      BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS: "0x0000000000000000000000000000000000000000"
EOF
cp "$SN/docker-compose.t13.yml" "$EXEC_DIR/docker-compose.t13-endereco-zero.yml"
sed 's/^/    │ /' "$SN/docker-compose.t13.yml"
em "$SN" executar "parar nó novo" dc_t13 stop novo
em "$SN" executar "subir nó novo com o endereço zero" dc_t13 up -d novo
sobe=não; esperar_ate "RPC do nó novo (não deve responder)" 60 responde "$PORTA_NOVO" && sobe=sim
CONSOLE=$(cd "$SN" && docker compose logs --since 2m novo 2>/dev/null)
info "linhas do plugin no console do nó novo:"
grep -E "invalid configuration|zero address|Error registering plugin" <<<"$CONSOLE" | head -4 | cut -c1-240 | sed 's/^/    │ /'
verificar T-13f "com o endereço zero no Ingress de contas, o nó NÃO sobe (RPC não responde)" "não" "$sobe"
verificar_que T-13g "plugin recusa o endereço zero com mensagem explícita" \
  "≥ 1 linha 'BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS must not be the zero address'" \
  "$(grep -c 'BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS must not be the zero address' <<<"$CONSOLE" || true) linha(s)" \
  test "$(grep -c 'BESU_PERMISSIONS_ACCOUNTS_CONTRACT_ADDRESS must not be the zero address' <<<"$CONSOLE" || true)" -ge 1

passo "Restaurar a configuração correta e verificar a recuperação"
em "$SN" executar "parar nó novo" dc_t13 stop novo
em "$SN" executar "subir nó novo com a configuração correta" docker compose up -d novo
esperar_ate "RPC do nó novo" 120 responde "$PORTA_NOVO" || abortar "nó novo não respondeu após restaurar a configuração"
t0=$SECONDS
esperar_ate "nó novo voltar a acompanhar a cadeia" 240 acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO" || true
fato t13.segundos_ate_recuperar "$((SECONDS - t0))"
BN=$(bloco_atual "$PORTA_NOVO"); BV=$(bloco_atual "$PORTA_VALIDATOR")
verificar_que T-13e "com a configuração corrigida, o nó se recupera sozinho e volta a acompanhar a cadeia" \
  "diferença ≤ 1 bloco" "validator $BV, novo ${BN:-?}" acompanha "$PORTA_VALIDATOR" "$PORTA_NOVO"
