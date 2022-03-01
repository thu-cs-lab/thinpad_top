#!/usr/bin/python3
PIPELINE_WORDS=101
import sys
raw_bits = ""
with open(sys.argv[1]) as rbd:
    line = 0
    for l in rbd.readlines():
        # if len(l) == 0: continue
        l = l.rstrip()
        assert len(l) == 32
        line += 1
        if line <= PIPELINE_WORDS: continue
        raw_bits += l[::-1]
with open(sys.argv[2]) as ll:
    elements = []
    for l in ll.readlines():
        if not l.startswith("Bit"): continue
        fields = l.split()
        offset = int(fields[1])
        net = ""
        mem = ""
        for f in fields:
            if f.startswith("Net="):
                net = f[4:]
            elif f.startswith("Ram=") or f.startswith("Rom="):
                mem = f[4:]
        elements.append((offset, net, mem))
    elements.sort(key = lambda x: x[1])
    for l in elements:
        val = int(raw_bits[l[0]]) ^ 1 # value of FF is internally inverted
        print(f"Value {val}  {l[1]} {l[2]}")
