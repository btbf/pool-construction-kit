#!/bin/bash
# Note: Run where the payment addr and skey files reside
# Don't forget to run `source ~/.bashrc` and `export CARDANO_NODE_SOCKET_PATH=~/node/socket/node.socket`

echo '========================================================='
echo 'Querying utxo details of payment.addr'
echo '========================================================='​
UTXO0=$(cardano-cli shelley query utxo --address $(cat payment.addr) --mainnet | sed -n 3p) # Only takes the first entry (3rd line) which works for faucet. TODO parse response to derive multiple txin 
UTXO0H=$(echo $UTXO0 | egrep -o '[a-z0-9]+' | sed -n 1p)
UTXO0I=$(echo $UTXO0 | egrep -o '[a-z0-9]+' | sed -n 2p)
UTXO0V=$(echo $UTXO0 | egrep -o '[a-z0-9]+' | sed -n 3p)
echo $UTXO0

echo '========================================================='
echo 'Calculating minimum fee'
echo '========================================================='
CTIP=$(cardano-cli shelley query tip --mainnet | jq -r .slotNo)
TTL=$(expr $CTIP + 1000)
TXOUT=$(expr $UTXO0V - $2) 
rm draft.txraw 2> /dev/null
cardano-cli shelley transaction build-raw --tx-in $(echo $UTXO0H)#$(echo $UTXO0I) --tx-out $(echo $1)+$(echo $2) --tx-out $(cat payment.addr)+$(echo $TXOUT) --ttl ${TTL} --fee 0 --out-file dummy.txbody
FEE=$(cardano-cli shelley transaction calculate-min-fee \
--tx-body-file draft.txraw \
--tx-in-count 1 \
--tx-out-count 2 \
--witness-count 1 \
--byron-witness-count 0 \
--mainnet \
--protocol-params-file protocol.json | egrep -o '[0-9]+')

echo '========================================================='
echo 'Building transaction'
echo '========================================================='
TXOUT=$(expr $UTXO0V - $FEE - $2) 
# echo "--tx-in $(echo $UTXO0H)#$(echo $UTXO0I) --tx-out $(echo $1)+$(echo $2) --tx-out $(cat payment.addr)+$(echo $TXOUT) --ttl $TTL --fee $FEE --out-file tx.raw"
cardano-cli shelley transaction build-raw \
--tx-in $(echo $UTXO0H)#$(echo $UTXO0I) --tx-out $(echo $1)+$(echo $2) --tx-out $(cat payment.addr)+$(echo $TXOUT) --ttl $TTL --fee $FEE --out-file tx.raw

# SHOULD BE DONE OFFLINE FOR VALUABLE KEYS 
echo '========================================================='
echo 'Signing transaction'
echo '========================================================='
cardano-cli shelley transaction sign \
--tx-body-file tx.txraw \
--signing-key-file payment.skey \
--mainnet \
--out-file tx.signed

# SHOULD BE DONE ONLINE
echo '========================================================='
echo 'Submitting transaction'
echo '========================================================='
cardano-cli shelley transaction submit \
--tx-file tx.signed \
--cardano-mode \
--mainnet