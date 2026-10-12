#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""List the device names Linux 4.19 gives to DT-created devices, with a
24-bit FNV-1a hash of each name, to decode a probe marker painted on the
screen.

usage: dt-devname-hashes.py <file.dtb> [hash ...]
  without hashes: print "hash24 name" for every candidate
  with hashes (hex like 0x1a2b3c or 24 bits like 0001...): print the matches

Platform device names follow of_device_make_bus_id(): "<addr>.<name>" for the
first node upwards whose "reg" translates to a CPU address, prefixed by
"<basename>:" for each untranslatable node below it. I2C clients get
"<bus>-<addr>" for buses 0..15.
"""
import re
import subprocess
import sys


def parse(dtb):
    src = subprocess.run(['dtc', '-q', '-I', 'dtb', '-O', 'dts', dtb],
                         capture_output=True, text=True, check=True).stdout
    root, stack = None, []
    for line in src.split('\n'):
        s = line.strip()
        m = re.match(r'^(?:[\w,.-]+:\s*)?([\w,@.+\-/]+) \{$', s)
        if m:
            n = {'full': m.group(1), 'props': {}, 'kids': [],
                 'parent': stack[-1] if stack else None}
            if stack:
                stack[-1]['kids'].append(n)
            else:
                root = n
            stack.append(n)
        elif s == '};' and stack:
            stack.pop()
        elif stack:
            m = re.match(r'^([\w,#.+\-]+)(?: = (.*))?;$', s)
            if m:
                v = m.group(2)
                cells = None
                if v and v.startswith('<'):
                    cells = [int(x, 0) for x in re.findall(r'0x[0-9a-fA-F]+|\d+', v.split('>')[0])]
                stack[-1]['props'][m.group(1)] = cells if cells is not None else (v or '')
    return root


def cells(node, key, default):
    v = node['props'].get(key) if node else None
    return v[0] if isinstance(v, list) and v else default


def num(cs):
    r = 0
    for c in cs:
        r = (r << 32) | c
    return r


def translate(node):
    """Return the CPU address of node's first reg entry, or None."""
    reg = node['props'].get('reg')
    if not isinstance(reg, list) or not node['parent']:
        return None
    p = node['parent']
    na = cells(p, '#address-cells', 2)
    if na == 0 or len(reg) < na:
        return None
    addr = num(reg[:na])
    child = p
    while child['parent']:
        bus = child['parent']
        rng = child['props'].get('ranges')
        if rng is None:
            return None
        if isinstance(rng, list) and rng:
            ca, pa = cells(child, '#address-cells', 2), cells(bus, '#address-cells', 2)
            cs = cells(child, '#size-cells', 1)
            step = ca + pa + cs
            for i in range(0, len(rng) - step + 1, step):
                c, q, sz = num(rng[i:i+ca]), num(rng[i+ca:i+ca+pa]), num(rng[i+ca+pa:i+step])
                if c <= addr < c + sz:
                    addr = addr - c + q
                    break
            else:
                return None
        child = bus
    return addr


def bus_id(node):
    name, n = None, node
    while n['parent']:
        a = translate(n)
        short = n['full'].split('@')[0]
        if a is not None:
            part = '%x.%s' % (a, short)
            return part + (':' + name if name else '')
        name = n['full'] + (':' + name if name else '')
        n = n['parent']
    return name


def fnv24(s):
    h = 0x811c9dc5
    for b in s.encode():
        h = ((h ^ b) * 0x01000193) & 0xffffffff
    return h & 0xffffff


def walk(n):
    yield n
    for k in n['kids']:
        yield from walk(k)


def main():
    root = parse(sys.argv[1])
    names = set()
    for n in walk(root):
        if not n['parent'] or n['full'].startswith('__'):
            continue
        names.add(bus_id(n))
        reg = n['props'].get('reg')
        if isinstance(reg, list) and reg and cells(n['parent'], '#address-cells', 2) == 1:
            for bus in range(16):
                names.add('%d-%04x' % (bus, reg[0]))
    table = sorted((fnv24(x), x) for x in names if x)
    want = sys.argv[2:]
    if not want:
        for h, x in table:
            print('%06x %s' % (h, x))
        return
    for w in want:
        v = int(w, 2) if re.fullmatch(r'[01]{24}', w) else int(w, 16)
        hits = [x for h, x in table if h == v]
        print('%06x: %s' % (v, ', '.join(hits) if hits else '(no DT candidate)'))


if __name__ == '__main__':
    main()
