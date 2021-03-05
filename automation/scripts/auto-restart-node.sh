function is_synced {
  local sync_status=$(mina client status | grep 'Sync status' | cut -d':' -f2)
  if [ $? -ne 0 ];
  then
    echo Fail to fetch sync status
    return 0
  fi
  if [ $sync_status != 'Synced' ];
  then 
    echo Nodes not synced
    return 0
  fi
  local max_observed_block=$(mina client status | grep 'Max observed block height' | cut -d':' -f2)
  if [ $? -ne 0 ];
  then 
    echo Fail to fetch max_observed_block
    return 0
  fi
  local max_unvalidated_block=$(mina client status | grep 'Max observed unvalidated block height' | cut -d':' -f2)
  if [ $? -ne 0 ];
  then
    echo Fail to fetch max_unvalidated_block
    return 0
  fi
  local diff=$((max_unvalidated_block-max_observed_block))
  echo Difference between validated and unvalidated block height is $diff  
  test $diff -lt 10
  return
}

not_synced=0
while true 
do
  if is_synced;
  then
    echo Nodes has no sync issue
    not_synced=0
  else
    echo Node reports sync but is not synced
    not_synced=$(($not_synced+1))
  fi
  if [ $not_synced -gt 5 ];
  then mina client stop-daemon
  fi
  sleep 60
done