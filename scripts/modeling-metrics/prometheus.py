import os
import json
import requests
import numpy as np
import math

def run_curl(query,time,trace=False):
    token = open("auth.token").read().strip()
    cookies = {
        '_oauth2_proxy': token
    }
    headers = {
        # 'Cookie': '_oauth2_proxy=' + os.getenv('TOKEN', ''),
        'Content-Type': 'application/x-www-form-urlencoded',
    }

    params = {
        'query': query,
    }

    data = {
        'dedup': 'true',
        'partial_response': 'true',
        'time': time,
        'engine': 'prometheus',
    }
    response = requests.get(
        'https://thanos.gcp.o1test.net/api/v1/query',
        params=params,
        cookies=cookies,
        headers=headers,
        data=data,
        verify=False,
    )
    if trace:
        print(response)
    return response.content


def raw_query(query,time,trace=False):
    path = 'data/query_' + str(time) + '_' + query + '.json'
    if not(os.path.exists(path)):
        if not(os.path.exists('data')):
            os.mkdir('data')
        with open(path, 'wb') as f:
            f.write(run_curl(query,time,trace=trace))
    return json.load(open(path))

def query(query,time,trace=False,grad=False):
    raw = raw_query(query,time,trace=trace)
    results = raw['data']['result']
    data = {}
    for res in results:
        source = res['metric']['service']
        data[source] = np.array([(np.datetime64(math.floor(t),'s'),float(v)) for [t,v] in res['values'] ])
        if grad and len(data[source]) > 1 :
            tp = np.transpose(data[source])
            tp[1] = np.gradient(tp[1])
            data[source] = np.transpose(tp)
    return data
