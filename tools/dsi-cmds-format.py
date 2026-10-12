#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reformat a qcom,mdss-dsi-*-command property (as decompiled by dtc, either
as a byte string or as 32-bit cells) into one DSI command per line, in the
usual CAF panel dtsi layout:

    <dtype> <last> <vc> <ack> <wait ms> <len hi> <len lo>  <payload...>

usage: dsi-cmds-format.py <dts-file> <property> [indent]
"""
import re
import sys

DCS = {
    0x01: 'soft_reset', 0x10: 'enter_sleep_mode', 0x11: 'exit_sleep_mode',
    0x13: 'enter_normal_mode', 0x20: 'exit_invert_mode', 0x28: 'set_display_off',
    0x29: 'set_display_on', 0x34: 'set_tear_off', 0x35: 'set_tear_on',
    0x36: 'set_address_mode', 0x3a: 'set_pixel_format', 0x51: 'set_display_brightness',
    0x53: 'write_control_display', 0x55: 'write_power_save',
}
DTYPE = {0x05: 'DCS short', 0x15: 'DCS short+param', 0x39: 'DCS long',
         0x29: 'generic long', 0x23: 'generic short 2', 0x13: 'generic short 1'}


def read_bytes(src, prop):
    m = re.search(re.escape(prop) + r'\s*=\s*([<\[])([^>\]]*)[>\]]', src)
    if not m:
        sys.exit('property not found: ' + prop)
    if m.group(1) == '[':
        return [int(x, 16) for x in m.group(2).split()]
    out = []
    for cell in m.group(2).split():
        v = int(cell, 16)
        out += [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]
    return out


def main():
    src = open(sys.argv[1]).read()
    prop = sys.argv[2]
    ind = sys.argv[3] if len(sys.argv) > 3 else '\t\t'
    b = read_bytes(src, prop)
    lines, i = [], 0
    while i < len(b):
        if i + 7 > len(b):
            sys.exit('truncated header at byte %d' % i)
        dlen = (b[i + 5] << 8) | b[i + 6]
        cmd = b[i:i + 7 + dlen]
        if len(cmd) < 7 + dlen:
            sys.exit('truncated payload at byte %d' % i)
        lines.append(cmd)
        i += 7 + dlen
    print('%s%s = [' % (ind, prop))
    for cmd in lines:
        hdr = ' '.join('%02X' % x for x in cmd[:7])
        pay = ' '.join('%02X' % x for x in cmd[7:])
        note = ''
        if cmd[0] in (0x05, 0x15, 0x39) and len(cmd) > 7 and cmd[7] in DCS:
            note = '  /* %s */' % DCS[cmd[7]]
        if cmd[4]:
            note = (note[:-3] + ', ' if note else '  /* ') + 'wait %d ms */' % cmd[4]
        print('%s\t%s  %s%s' % (ind, hdr, pay, note))
    print('%s];' % ind)
    sys.stderr.write('%d commands, %d bytes\n' % (len(lines), len(b)))


if __name__ == '__main__':
    main()
