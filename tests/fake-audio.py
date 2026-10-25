import sys, time
print('0.65 0.8 0.12', flush=True)
for _ in range(100):
    print('0.65 0 0.12', flush=True)
    time.sleep(.05)
