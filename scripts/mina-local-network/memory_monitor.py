import collections
import os
import re
import time
import csv
import psutil
import signal
import sys
import argparse

import math

class MinaProcess:
    def __init__(self,node_name):
        self.node_name = node_name
        self.mina_process = "mina.exe"
        self.metrics = {
            "main":[],
            "prover":[],
            "verifier":[],
            "vrf":[]
        }

    def headers(self):
        return  [self.node_name,f"{self.node_name}_prover", f"{self.node_name}_verifier", f"{self.node_name}_vrf"]

    def get_node_name_process(self,p):
        process_name = None
        for arg in p.cmdline():
            if m := re.match(f".*/nodes/(.*)/.*", arg):
                process_name = m.group(1)
                return process_name
        return process_name

    def is_mina_process(self,p):
        try:
            return ((self.mina_process in p.name() ) and
                (self.node_name == self.get_node_name_process(p)) and
                ("daemon" in p.cmdline()))
        except:
            return False


    def append_vrf(self,value):
        self.metrics["vrf"].append(value)
    def append_verifier(self,value):
        self.metrics["verifier"].append(value)
    def append_prover(self,value):
        self.metrics["prover"].append(value)

    def append(self,value):
        self.metrics["main"].append(value)

    def append_zeroes(self):
        self.append_vrf(0)
        self.append_verifier(0)
        self.append_prover(0)
        self.append(0)

    def metrics_values(self,row):
        row_values = []
        for values in self.metrics.values():
            row_values.append(values[row])
        return row_values

    def len(self):
        assert len(self.metrics["vrf"]) == len(self.metrics["prover"]) == len(self.metrics["verifier"]) == len(self.metrics["main"])
        return  len(self.metrics["vrf"])


def convert_size(size_bytes):
    return str(size_bytes/ 1024 / 1024)

def processes(whales,fishes,nodes):
    processes = ["seed","snark_coordinator"]
    processes.extend([f"whale_{i}" for i in range(0,whales)])
    processes.extend([f"fish_{i}" for i in range(0,fishes)])
    processes.extend([f"node_{i}" for i in range(0,nodes)])

    return list([MinaProcess(x) for x in processes])


def write_header(file,columns):
    with open(file, 'w') as csvfile:
        writer = csv.writer(csvfile, delimiter=',',)
        writer.writerow(columns)

def write_line(file,columns):
    with open(file, 'a') as csvfile:
        writer = csv.writer(csvfile, delimiter=',',)
        writer.writerow(columns)

def main(whales,fishes,nodes,file,interval):

   mina_processes = processes(whales,fishes,nodes)
   headers = []

   for x in mina_processes:
       headers.extend(x.headers())

   write_header(file, headers)

   print("Press Ctrl +c to finish")

   while True:
       for x in mina_processes:
            matches = list(filter(lambda p: x.is_mina_process(p),  psutil.process_iter()))
            if len(matches) == 0 :
                x.append_zeroes()
            else:
                p = matches[0]
                try:
                        children =  sorted(p.children(), key=lambda x: x.create_time())

                        def get_mem_for_child_or_default(child):
                            if not child:
                                return  0
                            else:
                                return  convert_size(child.memory_info()[0])

                        if len(children) > 2 :
                            x.append_vrf(get_mem_for_child_or_default(children[2]))
                            x.append_verifier(get_mem_for_child_or_default(children[1]))
                            x.append_prover(get_mem_for_child_or_default(children[0]))
                        elif len(children) > 1:
                            x.append_vrf(0)
                            x.append_verifier(get_mem_for_child_or_default(children[1]))
                            x.append_prover(get_mem_for_child_or_default(children[0]))
                        elif len(children) > 0:
                            x.append_vrf(0)
                            x.append_verifier(0)
                            x.append_prover(get_mem_for_child_or_default(children[0]))
                        else:
                            x.append_vrf(0)
                            x.append_verifier(0)
                            x.append_prover(0)

                        x.append(convert_size(p.memory_info()[0]))

                except (psutil.NoSuchProcess, psutil.ZombieProcess):
                    pass

       last_row = mina_processes[0].len()
       row = []
       for proc in mina_processes:
          row.extend(proc.metrics_values(last_row -1))
       write_line(file, row)

       time.sleep(interval)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='local network metrics',
        description='Program to measure local network mem usage')

    parser.add_argument('-o', '--output-file', default="metrics.csv")
    parser.add_argument('-w', '--whales', default=2, type=int)
    parser.add_argument('-f', '--fishes', default=1, type=int)
    parser.add_argument('-n', '--nodes', default=1, type=int)
    parser.add_argument('-i', '--interval', type=float, default=0.5)

    args = parser.parse_args()

    main(args.whales,args.fishes,args.nodes,args.output_file,args.interval)