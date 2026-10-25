"""Synthetic lyrics for the process/selection/seek smoke test, no network."""
import json
import sys
import time
track = json.load(sys.stdin)
if track['title'] == 'Slow':
    time.sleep(2)
else:
    time.sleep(.03)
if track['title'] == 'Plain':
    print(json.dumps({'status':'plain','source':'Fixture plain','lines':[],'plainText':'\n'.join('Искусственная строка ' + str(i) for i in range(30))}))
elif track['title'] == 'Broken':
    print('{bad JSON')
else:
    print(json.dumps({'status':'synced','source':'Fixture ' + track['title'],
                      'lines':[{'t':0,'text':'Начало ' + track['title']},{'t':5,'text':''},{'t':6,'text':'Продолжение ' + track['title']}],
                      'plainText':'Искусственный текст для проверки'}))
