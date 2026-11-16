#!/usr/bin/env bash
# End-to-end demo: compile the Fe Market, deploy it to a local anvil chain and
# run a full lifecycle (buy, price moves, sell, resolve, redeem, sweep), then a
# second market through the timeout/cancel/refund path. Needs fe + foundry.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.fe/bin:$HOME/.foundry/bin:$PATH"
PORT=${PORT:-8547}; RPC=http://127.0.0.1:$PORT
fe build >/dev/null
anvil --port "$PORT" --silent & ANVIL=$!; trap 'kill $ANVIL 2>/dev/null' EXIT
for _ in $(seq 50); do cast chain-id --rpc-url $RPC >/dev/null 2>&1 && break; sleep 0.1; done
# anvil's well-known dev keys (local chain only)
K0=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80   # creator
K1=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d   # alice
K2=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a   # bob
A1=$(cast wallet address $K1); A2=$(cast wallet address $K2); A0=$(cast wallet address $K0)
e() { cast --to-unit "$1" ether; }
send() { cast send --rpc-url $RPC --private-key "$@" >/dev/null; }
call() { cast call --rpc-url $RPC "$@"; }
num() { call "$@" | awk '{print $1}'; }
deploy() { # b n deadline subsidy
  local args; args=$(cast abi-encode "c(uint256,uint256,uint256)" "$1" "$2" "$3")
  cast send --rpc-url $RPC --private-key $K0 --value "$4" --create "$(cat out/Market.bin)${args#0x}" --json | jq -r .contractAddress
}
prices() { local s=""; for i in $(seq 0 $(($2-1))); do s+="  p$i=$(printf '%.4f' "$(e "$(num "$1" 'price(uint256)(uint256)' $i | cut -d' ' -f1)")")"; done; echo "$s"; }

B=10000000000000000000   # b = 10 (WAD)
NOW=$(cast block latest -f timestamp --rpc-url $RPC)
echo "== Market 1: 3 outcomes, b=10, subsidy 11 ETH (>= b*ln3 = 10.986)"
M=$(deploy $B 3 $((NOW+86400)) 11ether); echo "deployed $M (code $(( ($(cast codesize $M --rpc-url $RPC)) )) bytes)"
echo "start      $(prices $M 3)"
c=$(num $M 'quoteBuy(uint256,uint256)(uint256)' 0 5ether | cut -d' ' -f1); echo "alice buys 5 shares of #0, cost $(e $c) ETH"
send $K1 --value $c $M 'buy(uint256,uint256,address)' 0 5ether $A1; echo "after      $(prices $M 3)"
c=$(num $M 'quoteBuy(uint256,uint256)(uint256)' 1 8ether | cut -d' ' -f1); echo "bob buys 8 shares of #1, cost $(e $c) ETH (overpays 1 ETH, refunded)"
send $K2 --value $(( c + 1000000000000000000 )) $M 'buy(uint256,uint256,address)' 1 8ether $A2; echo "after      $(prices $M 3)"
p=$(num $M 'quoteSell(uint256,uint256)(uint256)' 0 2ether | cut -d' ' -f1); echo "alice sells 2 of #0 for $(e $p) ETH"
send $K1 $M 'sell(uint256,uint256,address)' 0 2ether $A1; echo "after      $(prices $M 3)"
echo "pool balance $(e $(cast balance $M --rpc-url $RPC)) ETH; outstanding #0=$(e $(num $M 'outstanding(uint256)(uint256)' 0 | cut -d' ' -f1)) #1=$(e $(num $M 'outstanding(uint256)(uint256)' 1 | cut -d' ' -f1))"
send $K0 $M 'resolve(uint256)' 0; echo "creator resolves outcome #0"
b0=$(cast balance $A1 --rpc-url $RPC); send $K1 $M 'redeem(address)' $A1; b1=$(cast balance $A1 --rpc-url $RPC)
echo "alice redeems 3 winning shares: +$(e $(( b1 - b0 ))) ETH (net of gas)"
send $K0 $M 'sweep(address)' $A0; echo "creator sweeps remainder; pool now $(e $(cast balance $M --rpc-url $RPC)) ETH"

echo; echo "== Market 2: timeout path (resolve-by already passed)"
M2=$(deploy $B 2 $((NOW-1)) 7ether); echo "deployed $M2 (2 outcomes, subsidy 7 ETH >= b*ln2 = 6.931)"
c=$(num $M2 'quoteBuy(uint256,uint256)(uint256)' 1 4ether | cut -d' ' -f1); send $K2 --value $c $M2 'buy(uint256,uint256,address)' 1 4ether $A2
echo "bob buys 4 of #1 for $(e $c) ETH; nobody resolves; anyone calls cancel()"
send $K1 $M2 'cancel()'; r=$(num $M2 'refundOf(address)(uint256)' $A2 | cut -d' ' -f1)
echo "bob's refund owed: $(e $r) ETH (= net collateral paid)"
send $K2 $M2 'refund(address)' $A2; echo "bob claims refund; pool now $(e $(cast balance $M2 --rpc-url $RPC)) ETH (subsidy left for creator sweep)"
