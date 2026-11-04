#!/usr/bin/env python3
"""Load the sources src/*.m into the MATLAB Function charts of afe_uvw_ctrl.slx without MATLAB.

    python3 tools/load_sources_into_slx.py                 # patches afe_uvw_ctrl.slx in place
    python3 tools/load_sources_into_slx.py in.slx out.slx  # or writes a copy

The .slx is a zip; each MATLAB Function block keeps its code as the text of <P Name="script"> inside
simulink/stateflow/chart_*.xml. For every chart the block name is read from <P Name="name">, the file
src/<name>.m is XML-escaped as MATLAB does (& < > " ') and written in place of the old script; nothing
else in the archive changes (entry order, compression and dates are kept, so that a file saved by
MATLAB stays otherwise identical). This is the MATLAB-free equivalent of update_afe_uvw_ctrl.m for a
change of the code only: ports, sizes and masks are not touched (see tools/make_afe_uvw_ctrl.py and
the README for those). The test bench test_afe_uvw_ctrl.slx links the library blocks and needs no patch.
"""
import os
import re
import sys
import zipfile

PKG = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(PKG, 'src')


def esc(text):
    return (text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                .replace('"', '&quot;').replace("'", '&apos;'))


def patch(src_slx, dst_slx):
    zin = zipfile.ZipFile(src_slx)
    out, done = {}, []
    for info in zin.infolist():
        data = zin.read(info.filename)
        if re.match(r'simulink/stateflow/chart_\d+\.xml$', info.filename):
            s = data.decode('utf-8')
            name = re.search(r'<P Name="name">([^<]*)</P>', s).group(1).split('/')[-1]
            src_file = os.path.join(SRC, name + '.m')
            if not os.path.isfile(src_file):
                raise SystemExit(f'{info.filename}: block {name} has no source {src_file}')
            code = open(src_file, encoding='utf-8').read().replace('\r\n', '\n')
            new, n = re.subn(r'(<P Name="script">).*?(</P>)', lambda m: m.group(1) + esc(code) + m.group(2),
                             s, count=1, flags=re.S)
            if n != 1:
                raise SystemExit(f'{info.filename}: no <P Name="script"> found')
            done.append((name, new != s))
            data = new.encode('utf-8')
        out[info.filename] = data
    with zipfile.ZipFile(dst_slx, 'w') as zout:
        for info in zin.infolist():
            i2 = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            i2.compress_type = info.compress_type
            i2.external_attr = info.external_attr
            zout.writestr(i2, out[info.filename])
    for name, changed in done:
        print(f'  {name:32s} {"updated" if changed else "unchanged"}')
    print(f'{len(done)} charts -> {dst_slx}')


if __name__ == '__main__':
    if len(sys.argv) == 1:
        f = os.path.join(PKG, 'afe_uvw_ctrl.slx')
        tmp = f + '.tmp'
        patch(f, tmp)
        os.replace(tmp, f)
    elif len(sys.argv) == 3:
        patch(sys.argv[1], sys.argv[2])
    else:
        raise SystemExit(__doc__)
