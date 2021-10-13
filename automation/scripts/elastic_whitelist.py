#!/usr/bin/env python3

"""
Input: current ansible inventory and adds some static whitelists ip
Output: applies aws elasticseach access policy
"""

import sys
import json
import pprint
import boto3
import requests
import socket
import dns.resolver

pp = pprint.PrettyPrinter(indent=4)

""" Get list of IPs from local ec2.json --- ec2.py > ec2.json """
def ips_from_ec2_json(fname='ec2.json'):
    iplist = []
    with open(fname) as jsonfile:
        data = json.load(jsonfile)
    for hostname in data['key_testnet']:
        iplist.append(socket.gethostbyname(hostname))
    return(iplist)

""" Get list of IPs from hosted_grafana """
def ips_from_hosted_grafana():
    iplist=[]
    # FIXME: They have a HTTP endpoint, but it was buggy and only returning a partial list
    #url = 'https://grafana.com/api/hosted-grafana/source-ips.txt'
    #r = requests.get(url)
    #for line in r.text.split("\n"):
    #    iplist.append(line)

    # DNS method (not broken, but requires dns module)
    myResolver = dns.resolver.Resolver()
    myAnswers = myResolver.query("src-ips.hosted-grafana.grafana.net", "A")
    for rdata in myAnswers:
        #print(rdata)
        iplist.append(str(rdata))

    return(iplist)

if __name__ == "__main__":
    proposed_ips = ips_from_ec2_json() + ips_from_hosted_grafana()

    # Load sensitive config
    try:
        with open('elastic_whitelist_config.json') as config_file:
            config = json.load(config_file)
            # Add static whitelist ips from config.json
            for ip in config['whitelist_ips']:
                proposed_ips.append(ip)
    except IOError as error:
        print('Error opening secrets config:', error)
        sys.exit(1)


    proposed_ips += ips_from_ec2_json()
    proposed_ips += ips_from_hosted_grafana()


    # Load current es access policy
    client = boto3.client('es')
    response = client.describe_elasticsearch_domains(
        DomainNames=[config['elastic_domain_name']])
    for domain in response['DomainStatusList']:
        ap = domain['AccessPolicies']
    ap = json.loads(ap)

    unique_proposed_ips = set(proposed_ips)
    proposed_ips = list(unique_proposed_ips)

    # override ips with new set (ugly)
    current_ap_ips = ap['Statement'][0]['Condition']['IpAddress']['aws:SourceIp']
    ap['Statement'][0]['Condition']['IpAddress']['aws:SourceIp'] = proposed_ips

    # Update existing access policy
    response = client.update_elasticsearch_domain_config(
        DomainName='testnet',
        AccessPolicies=json.dumps(ap),
    )
    print('ElasticSearch Domain:', config['elastic_domain_name'])
    print('New IPs:', proposed_ips)
    print('Result:', response['ResponseMetadata']['HTTPStatusCode'])
