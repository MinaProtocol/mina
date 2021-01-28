#!/bin/bash

#METRICS_PORT=8000 python3 prometheus_server.py
LOCAL_KUBERNETES=true KUBERNETES_NAMESPACE="watchdog-test" WATCHDOG_SERVER_PORT="tcp://localhost:5555" python3 cluster_crashes.py
