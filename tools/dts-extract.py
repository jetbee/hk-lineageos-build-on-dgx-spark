#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Extract one node from a decompiled DTS (dtc -I dtb -O dts output) and
rewrite raw phandle numbers into &label references, so the node can be
pasted into a kernel tree as a dtsi fragment.

usage: dts-extract.py <decompiled.dts> <node-name-or-path> [--as-ref LABEL]

Labels come from the /__symbols__ node, which dtc emits when the dtb was
built with -@. Only properties known to hold phandles are rewritten.
"""
import re
import sys

PHANDLE_LIST = re.compile(r'(-supply|^pinctrl-\d+|^qcom,panel-supply-entries|'
                          r'^qcom,dsi-pref-prim-pan|^qcom,mdss-fb-map-\w+|'
                          r'^qcom,mdss-mdp|^interrupt-parent)$')
GPIO_PROP = re.compile(r'(^gpios$|-gpio|-gpios|^qcom,platform-[\w-]*gpio|'
                       r'^qcom,platform-lcd-vdd-en\d*|^qcom,platform-epd-i2c-en)$')


def parse(lines):
    """Return list of (depth, path, start, end) for every node."""
    nodes, stack = [], []
    for i, l in enumerate(lines):
        s = l.strip()
        m = re.match(r'^([\w,@.+\-/]+) \{$', s)
        if m:
            name = m.group(1)
            parent = stack[-1][0] if stack else ''
            path = '/' if name == '/' else (parent.rstrip('/') + '/' + name)
            stack.append((path, i))
        elif s == '};' and stack:
            path, start = stack.pop()
            nodes.append((path, start, i))
    return nodes


def main():
    src, want = sys.argv[1], sys.argv[2]
    as_ref = sys.argv[4] if len(sys.argv) > 4 and sys.argv[3] == '--as-ref' else None
    lines = open(src).read().split('\n')
    nodes = parse(lines)
    by_path = {p: (a, b) for p, a, b in nodes}

    # label -> path, from __symbols__
    sym = {}
    if '/__symbols__' in by_path:
        a, b = by_path['/__symbols__']
        for l in lines[a + 1:b]:
            m = re.match(r'\s*([\w]+) = "([^"]+)";', l)
            if m:
                sym[m.group(2)] = m.group(1)
    # phandle -> label (or path if unlabelled)
    ph = {}
    for p, a, b in nodes:
        depth = lines[a].index(lines[a].lstrip())
        for l in lines[a + 1:b]:
            if l.index(l.lstrip() or 'x') != depth + 1 if l.strip() else True:
                continue
            m = re.match(r'\s*phandle = <(0x[0-9a-f]+)>;', l)
            if m:
                ph[int(m.group(1), 16)] = sym.get(p, '{' + p + '}')

    def ref(v):
        return '&' + ph[v] if v in ph and not ph[v].startswith('{') else \
            ('&' + ph[v] if v in ph else hex(v))

    match = [p for p in by_path if p == want or p.endswith('/' + want)]
    if len(match) != 1:
        sys.exit(f'node "{want}": {len(match)} matches {match[:5]}')
    a, b = by_path[match[0]]
    out = []
    for l in lines[a:b + 1]:
        m = re.match(r'^(\s*)([\w,#.+\-]+) = <([^>]*)>;$', l)
        if m and m.group(2) == 'phandle':
            continue
        if m and (PHANDLE_LIST.search(m.group(2)) or GPIO_PROP.search(m.group(2))):
            cells = [int(c, 16) for c in m.group(3).split()]
            if GPIO_PROP.search(m.group(2)):
                # tlmm and pmic gpios use 2 specifier cells after the phandle
                parts = []
                for k in range(0, len(cells), 3):
                    t = cells[k:k + 3]
                    parts.append(' '.join([ref(t[0])] + [str(x) for x in t[1:]]))
                l = f'{m.group(1)}{m.group(2)} = <{" ".join(parts)}>;'
            else:
                l = f'{m.group(1)}{m.group(2)} = <{" ".join(ref(c) for c in cells)}>;'
        out.append(l)
    base = len(out[0]) - len(out[0].lstrip())
    out = [x[base:] if x[:base].isspace() or not x[:base] else x for x in out]
    label = sym.get(match[0])
    if as_ref:
        out[0] = f'&{as_ref} {{'
    elif label:
        out[0] = f'{label}: {out[0]}'
    print(f'/* extracted from {src.split("/")[-1]}: {match[0]} */')
    print('\n'.join(out))
    unresolved = sorted({v for v in ph if ph[v].startswith('{')})
    if unresolved:
        pass


if __name__ == '__main__':
    main()
