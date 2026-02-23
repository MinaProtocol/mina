#!/usr/bin/python

import sys
import requests

url = sys.argv[1]
query = sys.argv[2]

response = requests.post(url=url, json={"query": query})
print("zkapp status code: ",  response.status_code)
print("zkapp response content: ", response.text)
print("zkapp request: ", response.request.body)
