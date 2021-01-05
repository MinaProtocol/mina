## Prometheus Monitoring Service

This is an opinionated setup of a Prometheus Monitoring Service. It is designed to monitor a Coda daemon and optional Echo and Faucet services. 

## Environment Variables 

`CODA_METRICS_URI`: **Required** The hostname:port combination of a Coda Daemon monitoring port. 
`FAUCET_METRICS_URI`: *Optional* The hostname:port combination of a Coda Faucet Service monitoring port.
`ECHO_METRICS_URI`: *Optional* The hostname:port combination of a Coda Echo Service monitoring port.
`REMOTE_WRITE_URI`: *Optional* The URI for a remote Prometheus instance to forward metrics to.
`REMOTE_WRITE_USERNAME`: *Optional* The Basic Auth username for the remote prometheus instance.
`REMOTE_WRITE_PASSWORD`: *Optional* The Basic Auth password for the remote prometheus instance.

Note: `REMOTE_WRITE_USERNAME` and `REMOTE_WRITE_PASSWORD` are **required** arguments when using `REMOTE_WRITE_URI`
