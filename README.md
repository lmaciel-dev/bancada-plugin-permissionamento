# Bancada de testes do plugin de permissionamento da RBB

> **Este é um fork, e ele difere da bancada original.** O repositório oficial é
> [RBBNet/bancada-plugin-permissionamento](https://github.com/RBBNet/bancada-plugin-permissionamento).
> Este fork é mantido por [@lmaciel-dev](https://github.com/lmaciel-dev) para validar de forma
> independente o plugin e as PRs que o corrigem, e acrescenta à original uma matriz de versões do
> Besu, ajustes de robustez e branches de validação de PRs (ver
> [Este fork](#este-fork-o-que-muda-em-relação-à-bancada-original)). Resultados obtidos aqui não são
> execuções oficiais da RBB.

Testes automatizados, reproduzíveis e verificáveis por terceiros do
[`besu-permissioning-plugin`](https://github.com/RBBNet/besu-permissioning-plugin) numa rede
de teste montada no padrão da Rede Blockchain Brasil (RBB).

## Por que esta bancada existe

O Hyperledger Besu removeu o permissionamento on-chain nativo na versão 25.6.0. O plugin
substitui essa funcionalidade. Antes de adotá-lo, precisamos comprovar, **com evidências que
qualquer pessoa possa conferir**, que ele se comporta como o esperado com os contratos de
permissionamento da RBB (gen02), inclusive durante a atualização gradual dos nós de uma rede
em funcionamento.

## Como a comprovação funciona

1. **Tudo é código.** A rede é montada do zero, os contratos são implantados, os nós são
   atualizados e os testes são executados por scripts deste repositório. Nenhum passo manual.
2. **O resultado esperado está escrito no código**, antes da execução. Cada verificação
   imprime o esperado, o obtido e o veredito.
3. **As execuções oficiais rodam no GitHub Actions**, em máquinas do GitHub. O log de cada
   execução, o resumo e os arquivos de evidência (logs dos nós, hashes de transação, blocos)
   ficam publicados na aba *Actions*, vinculados ao commit exato do código.
4. **Qualquer pessoa pode reproduzir** a execução na própria máquina com o mesmo comando.

## Este fork: o que muda em relação à bancada original

Este fork ([lmaciel-dev/bancada-plugin-permissionamento](https://github.com/lmaciel-dev/bancada-plugin-permissionamento))
parte da bancada da [RBBNet](https://github.com/RBBNet/bancada-plugin-permissionamento) no commit
[`f2de944`](https://github.com/RBBNet/bancada-plugin-permissionamento/commit/f2de944) e a estende.
A branch `main` deste fork reúne todas as extensões de uso geral; o que só faz sentido para uma PR
específica do plugin fica numa branch própria. Enquanto não forem incorporadas à original, as
extensões existem só aqui.

**1. Matriz de versões do Besu.** A original testa o plugin numa única versão do Besu; aqui cada
execução roda a bancada inteira em cada versão da matriz, com um job por versão e um relatório
consolidado. Detalhes na seção [Versões do Besu (matriz)](#versões-do-besu-matriz). O que isso já
revelou: a atualização gradual de uma rede 25.x para o Besu 26.6+ exige
`--Xbft-legacy-protocol-encoding` nos nós atualizados, sem o que a rede para (QBFT) quando metade
dos validadores é migrada; requisito que vale para a migração real da RBB.

**2. Robustez.** As chamadas RPC e de métricas usam `127.0.0.1` em vez de `localhost`. Em máquinas
onde `localhost` resolve primeiro para IPv6, cada chamada esperava a queda para IPv4 e estourava o
timeout de ~5 s do ethers na fase 03, abortando execuções locais de forma intermitente.

**3. Disparo por push.** Em forks o GitHub desabilita o disparo manual por padrão; aqui a bancada roda
também a cada push (ver [Como executar](#como-executar)).

**4. Validação independente das PRs do plugin** (uma branch por PR, a partir da matriz). Cada branch
usa o jar compilado a partir do commit da PR, publicado como prerelease no
[fork do plugin](https://github.com/lmaciel-dev/besu-permissioning-plugin/releases) com o SHA-256
conferido, e ajusta os testes cujo resultado esperado a PR muda: os itens 🐞, que demonstram
defeitos da v1.0.0-rc.1, passam a esperar a especificação. As branches ficam congeladas no commit
das execuções citadas nas reviews; quando a PR muda, a branch ganha um commit novo e uma execução nova.

| Branch | PR do plugin | O que a branch muda nos testes | Última execução | Situação da PR (21/10/2026) |
|---|---|---|---|---|
| `teste-pr7` | [#7](https://github.com/RBBNet/besu-permissioning-plugin/pull/7) fail-fast de configuração ([#4](https://github.com/RBBNet/besu-permissioning-plugin/issues/4)) | **T-13** (novo): nó com o endereço do Ingress de contas ausente ou igual ao endereço zero se recusa a subir com erro claro; a rede segue produzindo blocos e o nó se recupera ao corrigir a configuração. Contraparte do 🐞 T-10, que fica fora (roda T-04, T-05 e T-13) | [run 39605869797](https://github.com/lmaciel-dev/bancada-plugin-permissionamento/actions/runs/39605869797) (`bdcab5a`): ✅ 25.12.0 e 26.10.0 | aprovada, aguardando merge |
| `teste-pr6` | [#6](https://github.com/RBBNet/besu-permissioning-plugin/pull/6) nomes das métricas ([#3](https://github.com/RBBNet/besu-permissioning-plugin/issues/3)) | **T-07m** deixa de ser observação 🔎 e verifica os 6 contadores `besu_permissioning_*_total`, sem o prefixo antigo; **T-07n** lê os contadores pelos nomes novos | [run 39478944789](https://github.com/lmaciel-dev/bancada-plugin-permissionamento/actions/runs/39478944789) (`0be35d4`): ✅ 25.12.0 e 26.10.0 | mudanças pedidas: rebase sobre `develop` |
| `teste-pr5` | [#5](https://github.com/RBBNet/besu-permissioning-plugin/pull/5) consulta direta aos Ingress ([#2](https://github.com/RBBNet/besu-permissioning-plugin/issues/2)) | **T-08** e **T-09** deixam de ser 🐞: o nó entrante é recusado pelo plugin do nó remoto e, cadastrado, conecta e sincroniza; o observer importa o bloco da 1ª transação sem `BREACH_OF_PROTOCOL`. **T-05i** confere que o plugin não resolve mais o endereço do Rules | [run 39597059182](https://github.com/lmaciel-dev/bancada-plugin-permissionamento/actions/runs/39597059182) (`dba7f73`): ✅ 25.12.0; ❌ 26.10.0 só no T-08f, pela limitação da [#8](https://github.com/RBBNet/besu-permissioning-plugin/issues/8) (corrigida pela #11) | mudanças pedidas: rebase sobre `develop` (conflito com a #11) |

As reviews publicadas em cada PR trazem os links das execuções e a análise das falhas.

## Regra de dados: somente dados sintéticos

Este repositório é público. Por isso:

- **Usamos apenas dados sintéticos e descartáveis:** contas de teste de conhecimento público
  (Hardhat e roteiros da RBB) e chaves de nós geradas a cada execução.
- **É proibido incluir qualquer informação da mainnet ou da testnet da RBB:** enodes, IPs,
  portas, contas, arquivos de gênesis reais e listas de nós ou de participantes.
- **É proibido copiar ou referenciar conteúdo de repositórios privados.**
- **Nenhum segredo real.** Se um dia for necessário algum, ele entra como *secret* do
  GitHub Actions, nunca no código.

O histórico do Git é permanente: apagar um arquivo não o remove do histórico. Na dúvida,
não faça o commit. O repositório tem varredura automática de segredos (gitleaks) a cada push.

## Como executar

**Na sua máquina:** requer Docker (com Compose), Node.js 20+, git, jq, curl e python3.

```bash
./executar.sh                  # executa tudo e derruba a rede ao final
MANTER_REDE=1 ./executar.sh    # mantém a rede de pé para inspeção (RPC nas portas 20001–20003)
```

Para desenvolvimento, `TESTES="T11 T12" ./executar.sh` monta a rede e roda só os testes indicados (o filtro aparece no relatório). As execuções oficiais rodam todos.

Cada execução gera `execucoes/<data-hora>/`, com o relatório `resumo.md` e todas as
evidências. O código de saída é 0 se todas as verificações passarem.

Por padrão, os nós migrados para o plugin usam a versão de referência do Besu (25.12.0). Para as
outras versões da [matriz](#versões-do-besu-matriz):

```bash
BESU_VERSAO_PLUGIN=26.10.0 ./executar.sh         # uma execução numa versão da matriz
./executar-matriz.sh                             # uma execução por versão, em sequência, e o consolidado
BESU_VERSOES="26.10.0" ./executar-matriz.sh      # só as versões indicadas
```

O `executar-matriz.sh` grava o relatório consolidado em `execucoes/matriz-<data-hora>/resumo.md`.

**No GitHub:** aba *Actions* → *Bancada* → *Run workflow*. Opcionalmente, informe as versões do
Besu (vazio = matriz inteira) e um filtro de testes. Cada versão roda num job próprio, em paralelo,
numa máquina limpa; ao final, o job *Consolidado da matriz* junta os resultados. A página da
execução mostra o log de cada passo, o resumo de cada versão e o consolidado; as evidências de cada
versão ficam anexadas como um artefato separado. No repositório da RBBNet a bancada só roda quando
disparada assim; em forks, onde o GitHub desabilita o disparo manual por padrão, ela roda também a
cada push.

## Versões do Besu (matriz)

O plugin declara compatibilidade com o "Besu 25.12.0+ e 26.x", mas depende da API de plugins do
Besu, que muda entre versões. Compatibilidade, portanto, não se presume: **cada versão em que o
plugin pode ser usado precisa ser comprovada com a bancada inteira.** Por isso a versão do Besu é uma
dimensão da bancada, e cada versão testada tem um motivo para estar lá:

| Besu | Papel | Por que esta versão |
|---|---|---|
| 25.5.0 | rede de partida (nós nativos) | É a versão da RBB hoje. Foi a última com permissionamento on-chain nativo (removido na [25.6.0](https://github.com/hyperledger/besu/pull/8597)), e a RBB está restrita a ela até a conclusão do plugin ([ata 48 do Comitê Executivo](https://github.com/RBBNet/rbb/tree/master/governanca/reunioes_comite_executivo), 10/09/2026; [roteiro de adição de nós](https://github.com/RBBNet/rbb/blob/master/roteiro_adicao_nos.md)). Toda execução parte dela, como uma rede da RBB em produção. |
| **25.12.0** | nós com plugin: **referência** | Versão contra a qual o plugin v1.0.0-rc.1 é compilado: exercita o plugin sem nenhuma adaptação de API. Padrão das execuções. |
| **26.10.0** | nós com plugin: **ponta** | Última release estável do Besu. Cobre as mudanças de API da linha 26 que afetam o plugin (ex.: `Transaction.getValue()` passa a devolver `Wei` na 26.8.0, tratado pelo plugin por reflexão) e é a candidata natural a alvo de uma migração feita agora. |

As versões dos nós com plugin formam a matriz (`BESU_MATRIZ_PLUGIN`, em `versoes.env`): uma linha
por versão, com a imagem fixada por digest, a versão que o nó informa e as opções de migração que a
versão exige. **A RBB ainda não definiu a
versão-alvo da migração**; quando definir, ela entra na matriz como mais uma linha.

Como cada execução usa a matriz:

- **Só os nós com plugin mudam de versão.** A rede é sempre montada no Besu 25.5.0 nativo e os
  testes migram os nós, um a um, para a versão da matriz em teste. Assim, cada execução também
  comprova a atualização gradual de 25.5.0 para aquela versão.
- **Imagens fixadas por digest.** Uma tag do Docker Hub pode ser republicada; o digest não. A mesma
  linha da matriz executa sempre o mesmo binário.
- **Conferência antes da rede (P-02).** Na fase 00, a imagem informa a própria versão
  (`besu --version`) e ela é comparada com a registrada na matriz. Uma linha errada aborta a execução
  logo no início, em vez de gerar falhas espalhadas pelos testes.
- **Versão informada registrada à parte.** As verificações de versão (T-05a, T-11, T-12) comparam
  `web3_clientVersion` com a 3ª coluna da matriz, porque a versão informada pode diferir da tag: a
  `26.5.0` do Docker Hub, por exemplo, tem o mesmo digest da `26.5.0-RC2` e informa `v26.5.0-RC2`.
- **Opções de migração por versão.** Algumas versões exigem opções nos nós atualizados enquanto a
  rede ainda tem nós 25.x. A matriz as registra e elas são aplicadas a todo nó migrado; o P-03
  confere, na fase 00, que a imagem as aceita.
- **Versão em teste explícita.** A versão aparece no título e no ambiente do relatório
  (`besu.versao_plugin`, `besu.versao_informada_plugin`) e no nome do artefato no GitHub.
- **Uma versão fora da matriz é recusada**: a execução aborta e lista as versões disponíveis.

**Atualização gradual de 25.x para 26.6+ exige `--Xbft-legacy-protocol-encoding`.** A partir da
26.1.0, as mensagens de consenso QBFT mudaram de formato, e um validador 25.x não consegue decodificar
as propostas e trocas de rodada enviadas por um validador novo (`RLPException: Not at the end of the
current list` em `Proposal.decode` / `RoundChange.decode`). O Besu 26.6.0 criou a opção
`--Xbft-legacy-protocol-encoding` para isso, a ser usada "em cada nó Besu sendo atualizado"
([CHANGELOG 26.6.0](https://github.com/besu-eth/besu/blob/main/CHANGELOG.md), PR
[#10499](https://github.com/besu-eth/besu/pull/10499)). A bancada encontrou o problema na primeira
execução com a 26.10.0 sem a opção: com 1 de 4 validadores migrado, o migrado deixou de propor
blocos; com 2 de 4, a rede perdeu o quórum e parou (T-11). Por isso a matriz aplica
`BESU_XBFT_LEGACY_PROTOCOL_ENCODING=true` aos nós migrados para a 26.10.0. **Isto vale para a
migração real da RBB, não só para a bancada:** atualizar os validadores da 25.5.0 para a 26.6+ sem
essa opção para a rede quando metade deles estiver migrada.

**Relatório consolidado.** Além de uma linha por versão (resultado, verificações, defeitos 🐞 e
observações 🔎), o consolidado lista as **verificações com resultado diferente entre versões**: é ali
que aparece o que depende da versão do Besu. Uma versão que não chegou a gerar evidências aparece
como "sem resultado" e conta como falha da matriz.

**Incluir uma versão:**

1. Obtenha o digest (índice multiarquitetura) e a versão que o binário informa:
   ```bash
   curl -s https://hub.docker.com/v2/repositories/hyperledger/besu/tags/<versão> | jq -r .digest
   docker run --rm hyperledger/besu:<versão>@<digest> --version
   ```
2. Leia o CHANGELOG do Besu entre a 25.5.0 e a versão nova, procurando requisitos de atualização
   gradual (como `--Xbft-legacy-protocol-encoding`), e registre-os como opções de migração.
3. Acrescente a linha em `BESU_MATRIZ_PLUGIN` (`versoes.env`).
4. Execute `BESU_VERSAO_PLUGIN=<versão> ./executar.sh` ou dispare o workflow. A partir daí, a versão
   entra em toda execução da matriz.

## O que é executado hoje

| Etapa | O que faz | Estado resultante |
|---|---|---|
| Fase 00 | Registra o ambiente, baixa `start-network`, `Permissionamento` e `scripts-permissionamento` nos commits fixados em `versoes.env`, constrói o `rbb-cli`, instala as dependências, confere o SHA-256 do jar do plugin (P-01) e a versão informada pela imagem do Besu da matriz (P-02) | — |
| Fase 01 | Roteiro 1–3: chaves, gênesis (QBFT, Ingress do gen01 sem Rules), configuração e subida do validator (Besu 25.5.0, Forest) | **E0** |
| Fase 02 | Roteiro 4.1–4.4: deploy do gen01, subida do boot e do writer | **E1** |
| Fase 03 | Roteiro 4.5–4.9: deploy do gen02, cadastro dos nós, reapontamento dos Ingress | **E2** |
| T-01, T-02 | Linha de base do permissionamento **nativo**: conta permitida × conta não cadastrada | — |
| T-03 | Nativo × caminho do plugin em estados históricos (antes e depois das regras). Testa a lógica dos contratos via `eth_call`; **não** executa um nó com o plugin | — |
| T-04 | Permissionamento **nativo** de nós: um nó novo, não cadastrado, tenta conectar ao boot e é recusado (evidência: linha `Rejected enode://…` no log TRACE de permissionamento do boot). É cadastrado no NodeRulesV2 e conecta e sincroniza sozinho (linha `Permitted enode://…`) | **E3** |
| T-05 | Migração do nó "novo" para o **Besu da matriz (25.12.0 por padrão) com o plugin** v1.0.0-rc.1 (jar do release, SHA-256 conferido), mantendo chave e banco: plugin registrado com os Ingress da RBB, NodeRules do gen02 resolvido, reconexão e sincronização. Rede **mista** (1 nó com plugin, 3 nativos) | **E4** |
| T-06, T-07 | Transações enviadas **pelo nó com plugin**: conta permitida → minerada e importada por todos; conta não cadastrada → recusada com **o mesmo código e mensagem do nativo** (T-02). Contadores do plugin confirmam a checagem também na importação de blocos | — |
| 🐞 T-08 | **Demonstração permanente de defeito do plugin v1.0.0-rc.1.** Nó novo ("entrante") no Besu da matriz com o plugin, sincronizando desde o gênesis por static-node. O plugin do próprio entrante avalia a conexão no estado do gênesis, não resolve o NodeRules ("Could not resolve NodeRules contract address. Rejecting connection.") e recusa a própria saída — antes e depois do cadastro. Não conecta e fica no bloco 0 | **E5** |
| 🐞 T-09 | **Demonstração permanente de defeito do plugin v1.0.0-rc.1.** Nó com o plugin entrando como **observer** (boot como bootnode). Conecta pela exceção de bootnode do Besu, importa até o bloco anterior à 1ª transação da cadeia e, ao importar o bloco dela, o plugin não resolve o AccountRules ("Could not resolve AccountRules contract address. Rejecting transaction."). O Besu declara o bloco inválido ("Sender … is not on the Account Allowlist") e desconecta o par por BREACH_OF_PROTOCOL | **E6** |
| 🐞 T-10 | **Demonstração permanente de defeito do plugin v1.0.0-rc.1.** Nó com o plugin **sem** o endereço do Ingress de contas: o Besu sobe normalmente (só WARN/ERROR no log); o nó recusa transações até de conta permitida e declara **inválido** um bloco válido com transação, parando de acompanhar a cadeia. Corrigida a configuração, recupera-se sozinho | E7 → E8 |
| T-11 | **Validadores migrando para o plugin, um a um.** A rede passa a 4 validadores (os novos entram nativos, são cadastrados e votados via `qbft_proposeValidatorVote`) e cada um é migrado para o Besu da matriz + plugin mantendo chave e banco. A cada passo (1/4, 2/4, 3/4, 4/4): a rede segue produzindo blocos, o migrado volta a propor blocos, tx permitida enviada a ele é minerada e tx não cadastrada é recusada | E9 → E9.4 |
| T-12 | **Boot com o plugin barrando nós e rede inteira no plugin.** Boot migrado; um nó novo nativo e não cadastrado é recusado pelo **plugin do boot** (`OnChainNodePermissioningProvider: Rejected enode://…`); após o cadastro é permitido e baixa a cadeia. Writer e candidato migrados: todos os nós na versão da matriz com plugin; tx permitida minerada e importada por todos, tx não cadastrada recusada | E10 → E12 |
| 🔎 T-07m | Observação: as métricas existem, mas com nomes diferentes dos documentados no release (`besupermissioning_onchain_…` em vez de `besu_permissioning_…`) | — |

Os itens 🐞 esperam o comportamento **defeituoso** e passam enquanto o defeito se reproduzir; quando houver versão corrigida do plugin, testes novos a usarão esperando o comportamento correto.

Toda diferença deliberada em relação ao roteiro oficial é impressa na execução como
"DESVIO DO ROTEIRO" e listada no relatório.

## Estado

A bancada monta automaticamente a rede do
[roteiro de rede de teste da RBB](https://github.com/RBBNet/rbb/blob/master/roteiro_criacao_rede_teste.md)
(validator, boot e writer no Besu 25.5.0, com gen01 → gen02), verifica a linha de base do
permissionamento nativo e testa o plugin da migração do primeiro nó até a rede inteira (T-01 a
T-12), em cada versão do Besu da matriz. Os defeitos do plugin v1.0.0-rc.1 reproduzidos aqui
estão abertos como issues no repositório do plugin, e as PRs que os corrigem são validadas nas
branches descritas em [Este fork](#este-fork-o-que-muda-em-relação-à-bancada-original).

## Licença

[GPL-3.0](LICENSE), a mesma dos repositórios de permissionamento da RBB.
