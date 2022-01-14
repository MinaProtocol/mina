#!/usr/bin/env python3

# This is a temporary hack for the integration test framework to be able to stop
# and start nodes dyamically in a kubernetes environment. This script takes
# mina arguments and will start and monitor a mina process with those arguments.
# If a SIGUSR1 signal is sent, it will stop this process, and if a SIGUSR2 is
# sent, it will resume the process. Since this script is a hack, there are some
# shortcomings of the script. Most notably:
#   - the script will stack overflow after a lot of restarts are issued
#   - the script does not attempt to handle errors from the tail child process

import os
import os.path
from pathlib import Path
import signal
import subprocess
import sys
import time
from socketserver import TCPServer
from http.server import HTTPServer, BaseHTTPRequestHandler

# all signals handled by this program
ALL_SIGNALS = [signal.SIGCHLD, signal.SIGUSR1, signal.SIGUSR2]
SCRIPT_LOG_OUTPUT_FILENAME = "mina_daemon_puppeteer.log"

script_log_output_file = None
active_daemon_request = False
inactive_daemon_request = False
tail_process = None
mina_process = None
daemon_args = sys.argv[1:] if len(sys.argv) > 1 else []

TCPServer.allow_reuse_address = True
HTTPServer.timeout = 1

def log(s):
  line = "mina_daemon_puppeteer_script: "+s
  script_log_output_file.write("%s\n" % line)
  script_log_output_file.flush()

def log_event(puppeteer_event_type, message):
  line = '{"puppeteer_script_event": true, "puppeteer_event_type": "' + puppeteer_event_type + '", "message":"'+ message+'"}'
  script_log_output_file.write("%s\n" % line)
  script_log_output_file.flush()

class MockRequestHandler(BaseHTTPRequestHandler):
  def do_GET(s):
    s.send_response(200)
    s.send_header('Content-Type', 'text/html')
    s.end_headers()
    s.wfile.write(b'<html><body>The daemon is currently offline.<br/><i>This broadcast was brought to you by the puppeteer mock server</i></body></html>')

def handle_child_termination(signum, frame):
  log("SIGCHLD received" )
  os.waitpid(-1, os.WNOHANG)

def handle_start_request(signum, frame):
  log("SIGUSR1 handle_start_request received, setting active_daemon_request to True" )
  global active_daemon_request
  active_daemon_request = True

def handle_stop_request(signum, frame):
  log("SIGUSR2 handle_stop_request received, setting inactive_daemon_request to True" )
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
  log("start_daemon called" )
  global mina_process
  with open('mina.log', 'a') as f:
    env = os.environ.copy()
    if os.path.isfile("/extra.env"): 
      # this doesn't support quotes or multiline variables
      with open("/extra.env", "r") as extra_env_file:
        for l in extra_env_file.read().splitlines():
          parts = l.split("=",1)
          env[parts[0]] = parts[1]
    mina_process = subprocess.Popen(
        ['mina'] + daemon_args,
        stdout=f,
        stderr=subprocess.STDOUT,
        env=env
    )
  log("touching /root/daemon-active" )
  Path('daemon-active').touch()
  log("daemon fully started" )
  # log_event("node_initialized", "node has been initialized")

def stop_daemon():
  log("stop_daemon called" )
  global mina_process
  mina_process.send_signal(signal.SIGTERM)

  child_pids = get_child_processes(mina_process.pid)
  log("stop_daemon, child_pids: %s" % ', '.join([str(i) for i in child_pids]))
  mina_process.wait()
  for child_pid in child_pids:
      log("waiting for child_pid: " + str(child_pid) )
      wait_for_pid(child_pid)
      log("done waiting for: " + str(child_pid) )
  log("removing /root/daemon-active" )
  Path('daemon-active').unlink()
  mina_process = None
  log("daemon fully stopped" )
  log_event("node_offline", "daemon is being stopped by puppeteer script and is going offline")

# technically, doing the loops like this will eventually result in a stack overflow
# however, you would need to do a lot of starts and stops to hit this condition

def inactive_loop():
  log("inactive_loop beginning" )
  global active_daemon_request
  server = None
  try:
    server = HTTPServer(('0.0.0.0', 3085), MockRequestHandler)
    while True:
      server.handle_request()
      signal.sigtimedwait(ALL_SIGNALS, 0)
      if active_daemon_request:
        log("inactive_loop: active_daemon_request received, starting daemon" )
        start_daemon()
        active_daemon_request = False
        break
  except Exception as err:
    log("inactive_loop experienced an error: ")
    log(err)
  finally:
    if server != None:
      server.server_close()
    log("inactive_loop terminating. mock server closed." )
    
  active_loop()

def active_loop():
  log("active_loop beginning" )
  global mina_process, inactive_daemon_request

  while True:
    signal.pause()
    status = mina_process.poll()
    if status != None:
      log("active_loop: status not None, cleaning up and exiting")
      cleanup_and_exit(status)
    elif inactive_daemon_request:
      log("active_loop: inactive daemon request detected, stopping daemon")
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
  script_log_output_file = open(SCRIPT_LOG_OUTPUT_FILENAME, 'w')
  log("starting...")
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
      ['tail', '-q', '-f', 'mina.log', '-f', '.mina-config/mina-prover.log', '-f', '.mina-config/mina-verifier.log', '-f' , '.mina-config/mina-best-tip.log', '-f', SCRIPT_LOG_OUTPUT_FILENAME]
  )

  inactive_loop()