import json

def lambda_handler(event, context):
    request = event['Records'][0]['cf']['request']
    uri = request['uri']

    if uri.endswith('/'):
        uri = uri + 'index.html'
    elif '.' not in uri:
        uri = uri + '/index.html'

    request['uri'] = uri
    return request
