#!/bin/sh
#seed=does-not-compute.o1test.net:8303

#spawn() { $@; echo "$?"; }
#daemon_args() { echo "-external-port $1 -peer $seed"; }
#spawn_daemon() { spawn $coda daemon $(daemon_args $1) $@; }
#spawn_named_daemon() { spawn_daemon $2 "$@ >$1.out 2>$1.err"; }

#proposer=$(spawn $coda daemon )

set -e

build_dir=./_build/default
coda=$build_dir/src/app/cli/src/coda.exe
logproc=$build_dir/src/app/logproc/logproc.exe
keypairs_json=$build_dir/src/lib/coda_base/sample_keypairs.json
config_dir=configs
keys_dir=keys
ip=10.111.14.110
sn=coda

time_offset=$(( $(date +%s) - $(date --date="2019-01-30 12:00:00-08:00" +%s) ))
prometheus_targets=''

mkdir -p configs
mkdir -p keys
chmod 700 keys

# TODO: make better
# NB. this does not need to be used if you are running the network only locally
forward_port() {
  port=$1
  protocol=$2

  set +e
  upnpc -a $ip $port $port $protocol >/dev/null
  set -e

#  set +e
#  upnpc -a $ip $port $port $protocol
#  status=$?
#  set -e
#
#  # 718 == conflicing mapping
#  # really, should just check first, but that's too much work right now
#  if ! ([ $status = 0 ] || [ $status = 718 ]); then
#    echo "Failed to forward ports using upnpc: $status" >&2
#    exit 1
#  fi
}

# TODO: bash array args
# NB. this function prepares and echos a shell command for executing a daemon
#     the arguments are as follows:
#       1) name (this is used for naming config and log directories)
#       2) base port (this is the base port, exclusive, for all the other ports this process will use)
#       3) seed peer (accepts "none")
#       4) propose key index (accepts "none")
#       5) snark worker key index (accepts "none")
daemon_cmd() {
  name=$1
  base_port=$2
  if [ "$3" != "none" ]; then seed="$3"; fi
  if [ -n "$4" ] && [ "$4" != "none" ]; then propose_key=$4; fi
  if [ -n "$5" ] && [ "$5" != "none" ]; then snark_key=$5; fi

  config="$config_dir/$name"
  client_port="$(( $base_port + 1 ))"
  external_port="$(( $base_port + 2 ))"
  gossip_port="$(( $base_port + 3 ))"
  rest_port="$(( $base_port + 4 ))"
  metrics_port="$(( $base_port + 5 ))"

  mkdir -p $config

  forward_port $external_port TCP
  forward_port $gossip_port UDP

  prometheus_targets="$prometheus_targets$(if [ -n "$prometheus_targets" ]; then echo ', '; fi)'127.0.0.1:$metrics_port'"

  args="\
    -log-json -log-level Trace \
    -config-directory $config \
    -client-port $client_port \
    -external-port $external_port \
    -rest-port $rest_port \
    -metrics-port $metrics_port"
  if [ -n "$seed" ]; then
    args="$args -peer $seed"
  fi
  if [ -n "$propose_key" ]; then
    jq -r ".[$propose_key].private_key" "$keypairs_json" \
      | xargs -0 printf '%s\n\n\n' \
      | $coda advanced wrap-key \
          -privkey-path keys/$name.kp \
          >/dev/null
    args="$args -propose-key keys/$name.kp"
  fi
  if [ -n "$snark_key" ]; then
    args="$args -run-snark-worker '$(jq -r ".[$snark_key].public_key" "$keypairs_json")'"
  fi

  echo "set -o pipefail && export CODA_PRIVKEY_PASS='' && export CODA_TIME_OFFSET=$time_offset && $coda daemon $args | $logproc"
}

# you can skip writing the shell files and just embed the "$(daemon_cmd ...)" directly in the tmux call, this just helps for debugging
daemon_cmd seed 17300 none 0 none > seed.sh
daemon_cmd worker 18300 127.0.0.1:17303 none 1 > worker.sh
tmux new-session -d -s "$sn" -n coda "(sh seed.sh) || sleep infinity"
tmux split-window -d -h -t "$sn:0" "sleep 25 && (sh worker.sh) || sleep infinity"

echo $prometheus_targets
echo "
scrape_configs:
  - job_name: "prometheus"
    scrape_interval: 2s
    static_configs:
      - targets: [$prometheus_targets]" > prometheus.yml
tmux new-window -t "$sn:1" "prometheus --config.file=prometheus.yml || sleep infinity"

tmux attach-session -t "$sn"
