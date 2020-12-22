NAMESPACE="pear2pear"

PODS=$(kubectl --namespace=$NAMESPACE get pods | egrep Running | awk '{ print $1 }' | egrep -v NAME | egrep 'producer|coordinator|seed|archive-node-dev')

for POD in $PODS; do
  PEERS_CMD="coda client status | grep Peers | sed 's/.*(//g' | sed 's/)//g'"
  EXTERNAL_IP_CMD="coda client status | grep 'External IP' | sed 's/.* //g'"
  LOCAL_IP_CMD="cat /proc/net/fib_trie | grep -e '|-- 10.' | head -n2 | tail -n1 | sed 's/.* //g'"

  if [[ "$POD" == *producer* ]]; then
    LOCAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c coda -- bash -c "cat /proc/net/fib_trie | grep -e '|-- 10.' | head -n2 | tail -n1 | sed 's/.* //g'")
    EXTERNAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c coda -- bash -c "coda client status | grep 'External IP' | sed 's/.* //g'")
    PEERS=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c coda -- bash -c "$PEERS_CMD")
  elif [[ "$POD" == *seed* ]]; then
    LOCAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c seed -- bash -c "cat /proc/net/fib_trie | grep -e '|-- 10.' | head -n2 | tail -n1 | sed 's/.* //g'")
    EXTERNAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c seed -- bash -c "coda client status | grep 'External IP' | sed 's/.* //g'")
    PEERS=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -c seed -- bash -c "$PEERS_CMD")
  else
    LOCAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -- bash -c "cat /proc/net/fib_trie | grep -e '|-- 10.' | head -n2 | tail -n1 | sed 's/.* //g'")
    EXTERNAL_IP=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -- bash -c "coda client status | grep 'External IP' | sed 's/.* //g'")
    PEERS=$(kubectl --namespace="$NAMESPACE" exec -it "$POD" -- bash -c "$PEERS_CMD")
  fi

  echo $POD
  echo $LOCAL_IP
  echo $EXTERNAL_IP
  echo $PEERS
  echo ""
done

# s/-[^-]*-[^-]*$//g
