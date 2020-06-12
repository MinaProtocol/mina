function cleanup()
{
  kill $(jobs -p)
  /etc/init.d/postgresql stop
  exit
}

trap cleanup TERM

/etc/init.d/postgresql start

coda-archive \
  -postgres-uri postgres://pguser:pguser@localhost:5432/archiver \
  -server-port 3086 &

sleep 5

coda daemon \
    -peer $PEER1 -peer $PEER2 \
    -archive-address 3086 \
    -config-directory /data/coda-config &

ls
