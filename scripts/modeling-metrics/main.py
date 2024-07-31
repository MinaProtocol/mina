import prometheus
import matplotlib.pyplot as plt
import numpy as np
import sys

data = {}
time = 1722432816
interval = '2w'

def get_data(query,label,trace=False,grad=False):
    res = prometheus.query(query + '[' + interval + ']',time,trace=trace,grad=grad)
    if trace:
        print(res)
    for key in res.keys():
        if not(key in data):
            data[key] = {}
        data[key][label] = res[key]



get_data('Coda_Block_producer_slots_won','slots_won')
get_data('Coda_Block_producer_blocks_produced','block_built')
get_data('Coda_Network_new_state_broadcasted','block_broadcast')

get_data('Coda_Block_producer_block_production_delay_sum','production_delay',grad=True)
get_data('Coda_Network_ipc_latency_ns_summary_sum','network_latency',grad=True)

def increases(metric):
    incs = []
    for ([[_,prev],[time,new]]) in zip(metric,metric[1:]):
        if new > prev:
            incs.append(time)
    return incs


all_block_data = {}


match input("Do you want histograms for each node? (y/n)").strip():
    case 'y' :
        histogram = True
    case _ :
        histogram = False

for node_key in data.keys() :
    if not("devnet-whale" in node_key):
        # lots of nodes don't have the right metrics
        continue
    node = data[node_key]
    dicts = {}
    for key in node.keys():
        dicts[key] = dict(node[key])

    # find events
    events = []
    for event_type in ['slots_won','block_built','block_broadcast']:
        for time in increases(node[event_type]):
            events.append([time,event_type])
    events.sort()
    if events == []:
        continue
    if events[0][1] == 'slots_won' :
        # If it starts on slots_won we don't know how that block went
        events = events[1:]
    blocks = []
    built = False
    broadcast = False
    for (i,event) in enumerate(events):
        match event:
            case [time,'slots_won']:
                blocks.append([time,built,broadcast])
                built = False
                broadcast = False
            case [time,'block_built']:
                built = True
            case [time,'block_broadcast']:
                broadcast = True

    # clasify
    block_data = {}
    block_data['failed_to_build'] = {'time' : []}
    block_data['failed_to_broadcast'] = {'time' : []}
    block_data['successful'] = {'time' : []}
    block_keys = ['block_broadcast','block_built','slots_won']
    for label in block_data :
        for metric in node :
            if key in block_keys:
                continue
            block_data[label][metric] = []
    for block in blocks:
        [time,built,broadcast] = block
        assert(not(broadcast and not(built)))
        if broadcast:
            label = "successful"
        elif built:
            label = "failed_to_broadcast"
        else:
            label = "failed_to_build"
        missing_keys = list(filter(lambda key: not (time in dicts[key]) and not(key in block_keys) ,node.keys()))
        if any(missing_keys) :
            print("Warn: missing data",node_key,time ,missing_keys)
            # This doesn't happen much so right now just warn and skip
            continue
        block_data[label]['time'].append(time)
        for key in node.keys():
            if key in block_keys:
                continue
            block_data[label][key].append(dicts[key][time])


    for label in block_data:
        if not(label in all_block_data):
            all_block_data[label] = {}
        for metric in block_data[label]:
            if not(metric in all_block_data[label]):
                all_block_data[label][metric] = []
            all_block_data[label][metric] += block_data[label][metric]


    #Plots a histogram of block status over time for each node
    if histogram :
        print(node_key
              ,len(block_data['successful']['time'])
              ,len(block_data['failed_to_broadcast']['time'])
              ,len(block_data['failed_to_build']['time'])
              )
        plt.hist([block_data['successful']['time']
                ,block_data['failed_to_broadcast']['time']
                ,block_data['failed_to_build']['time']
                ]
                ,color = ["blue","orange","red"]
                )
        plt.title(node_key)
        plt.legend(["successful","failed_to_broadcast","failed_to_build"])
        plt.show()



for label in all_block_data:
    print(label,len(all_block_data[label]['time']))

x = 'production_delay'
y = 'network_latency'
plt.scatter(np.array(all_block_data['successful'][x])
           ,np.array(all_block_data['successful'][y])
           ,color = 'blue')
plt.scatter(np.array(all_block_data['failed_to_broadcast'][x])
           ,np.array(all_block_data['failed_to_broadcast'][y])
           ,color = 'orange')
plt.scatter(np.array(all_block_data['failed_to_build'][x])
           ,np.array(all_block_data['failed_to_build'][y])
           ,color = 'red')
plt.xlabel(x)
plt.ylabel(y)
plt.legend(["successful","failed_to_broadcast","failed_to_build"])
plt.show()
