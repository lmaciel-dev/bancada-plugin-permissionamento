// Implanta um contrato a partir do bytecode de criação (gasPrice 0) e imprime o resultado em JSON.
// Uso: node implantar.js <url-rpc> <chave-privada> <bytecode-de-criação>
// Saída: {remetente, resultado: "IMPLANTADO"|"RECUSADA"|"ERRO", endereco?, hash?, bloco?, status?, erro?, codigo?, resumo}
const { ethers } = require('ethers');

(async () => {
  const [rpc, chave, bytecode] = process.argv.slice(2);
  const provedor = new ethers.JsonRpcProvider(rpc, undefined, { staticNetwork: true });
  const carteira = new ethers.Wallet(chave, provedor);
  const saida = { instante: new Date().toISOString(), rpc, remetente: carteira.address, bytecode };
  try {
    const tx = await carteira.sendTransaction({ data: bytecode, value: 0, gasPrice: 0, gasLimit: 200000, type: 0 });
    const recibo = await tx.wait(1, 60000);
    Object.assign(saida, {
      resultado: recibo.status === 1 && recibo.contractAddress ? 'IMPLANTADO' : 'ERRO',
      endereco: recibo.contractAddress, hash: tx.hash, bloco: recibo.blockNumber, status: recibo.status,
    });
  } catch (e) {
    const codigo = (e.error && e.error.code) || (e.info && e.info.error && e.info.error.code) || null;
    Object.assign(saida, {
      resultado: codigo !== null ? 'RECUSADA' : 'ERRO',
      erro: (e.error && e.error.message) || (e.info && e.info.error && e.info.error.message) || e.shortMessage || e.message || String(e),
      codigo,
    });
  }
  saida.resumo = saida.resultado === 'IMPLANTADO' ? `IMPLANTADO em ${saida.endereco}, status ${saida.status}`
    : saida.resultado === 'RECUSADA' ? `RECUSADA: ${saida.codigo} ${saida.erro}` : `ERRO: ${saida.erro || 'status ' + saida.status}`;
  console.log(JSON.stringify(saida));
  process.exit(0);  // o provedor do ethers mantém tentativas de conexão pendentes
})();
