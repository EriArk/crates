#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run the real existing TrainerOS SDK + TLS helper in an isolated server container."""
import argparse,json,pathlib,shlex,subprocess
p=argparse.ArgumentParser()
p.add_argument('--manifest',type=pathlib.Path,required=True)
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--case',choices=['2','16'],required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
identity=json.loads(a.manifest.read_text())['source_snapshot']
assert len(identity)==16 and all(c in '0123456789abcdef' for c in identity)
root='/home/abysscloud/traineros-micro-rally'
base=['docker','run','--rm','--network','none','--cpus','4','--memory','6g','--user','1000:1000','-e','HOME=/tmp','-e','QT_QPA_PLATFORM=offscreen',
      '-v',root+':/rally','-v','/home/abysscloud/traineros-account-ci-20261025:/work:ro',
      'traineros-golf-backend-ci:20261025']
def run(argv,name,timeout=120):
    r=subprocess.run(['ssh','books-server',' '.join(shlex.quote(x) for x in argv)],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    (a.output/name).write_text(r.stdout+r.stderr,encoding='utf-8')
    print((r.stdout+r.stderr)[-2500:],flush=True)
    if r.returncode: raise SystemExit(r.returncode)
build='/rally/network-build/'+identity
run(base+['cmake','-S','/rally/snapshots/'+identity+'/tests','-B',build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DTRAINEROS_SOURCE=/work/source','-DTRAINEROS_CORE=/work/build-trixie/libtrainer_core.a'],'configure.log')
run(base+['cmake','--build',build,'-j','2'],'build.log')
run(base+['env','TRAINEROS_TEST_RECORD_PYTHON=/usr/bin/python3','RALLY_TEST_GODOT=/rally/engine/godot','RALLY_TEST_PROJECT=/rally/snapshots/'+identity,build+'/rally-host-tests','groupRace:'+a.case], 'sdk-'+a.case+'.log',700)
