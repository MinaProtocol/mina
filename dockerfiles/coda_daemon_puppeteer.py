# This is a temporary hack for the integration test framework to be able to stop
# and start nodes dyamically in a kubernetes environment. This script takes
# coda arguments and will start and monitor a coda process with those arguments.
# If a SIGUSR1 signal is sent, it will stop this process, and if a SIGUSR2 is
# sent, it will resume the process. Since this script is a hack, there are some
# shortcomings of the script. Most notably:
#   - the script will stack overflow after a lot of restarts are issued
#   - the script does not attempt to handle errors from the tail child process

import os
from pathlib import Path
import signal
import subprocess
import sys
import time

active_daemon_request = False
inactive_daemon_request = False
tail_process = None
coda_process = None
daemon_args = sys.argv[1:] if len(sys.argv) > 1 else []

# just nooping on this signal suffices, since merely trapping it will cause
# `signal.pause()` to resume
def handle_child_termination(signum, frame):
  pass

def handle_start_request(signum, frame):
  global active_daemon_request
  active_daemon_request = True

def handle_stop_request(signum, frame):
  global inactive_daemon_request
  inactive_daemon_request = True

def get_child_processes(pid):
  result = subprocess.run(
    ['ps', '-o', 'pid=', '--ppid', str(pid)],
    stdout=subprocess.PIPE
  )
  output = result.stdout.decode('ascii')
  return list(map(int, filter(lambda s: len(s) > 0, output.split(' '))))

def pid_is_running(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True

def wait_for_pid(pid):
    while pid_is_running(pid):
        time.sleep(0.25)

def start_daemon():
  global coda_process
  with open('mina.log', 'a') as f:
    coda_process = subprocess.Popen(
        ['mina'] + daemon_args,
        stdout=f,
        stderr=subprocess.STDOUT
    )
  Path('daemon-active').touch()

def stop_daemon():
  global coda_process
  coda_process.send_signal(signal.SIGTERM)

  child_pids = get_child_processes(coda_process.pid)
  coda_process.wait()
  for child_pid in child_pids:
      wait_for_pid(child_pid)
  Path('daemon-active').unlink()
  coda_process = None

# technically, doing the loops like this will eventually result in a stack overflow
# however, you would need to do a lot of starts and stops to hit this condition

def inactive_loop():
  global active_daemon_request
  while True:
    signal.pause()
    if active_daemon_request:
      start_daemon()
      active_daemon_request = False
      break

  active_loop()

def active_loop():
  global coda_process, inactive_daemon_request
  while True:
    signal.pause()
    status = coda_process.poll()
    if status != None:
      cleanup_and_exit(status)
    elif inactive_daemon_request:
      stop_daemon()
      inactive_daemon_request = False
      break

  inactive_loop()

def cleanup_and_exit(status):
  time.sleep(5)
  tail_process.terminate()
  tail_process.wait()
  sys.exit(status)

if __name__ == '__main__':
  signal.signal(signal.SIGCHLD, handle_child_termination)
  signal.signal(signal.SIGUSR1, handle_stop_request)
  signal.signal(signal.SIGUSR2, handle_start_request)

  Path('.mina-config').mkdir(exist_ok=True)
  Path('mina.log').touch()
  Path('.mina-config/mina-prover.log').touch()
  Path('.mina-config/mina-verifier.log').touch()
  Path('.mina-config/mina-best-tip.log').touch()

  # currently does not handle tail process dying
  tail_process = subprocess.Popen(
      ['tail', '-q', '-f', 'mina.log', '-f', '.mina-config/mina-prover.log', '-f', '.mina-config/mina-verifier.log', '-f' , '.mina-config/mina-best-tip.log']
  )

  start_daemon()
  active_loop()
