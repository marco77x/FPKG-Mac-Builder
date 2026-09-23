#!/usr/bin/env python3
"""Read-only nested PFS adapter and verified package build coordinator."""
import contextlib
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'vendor'))
from mkpfs.pfs import (open_inner_file_view, inspect_pfs_image,
                       iter_inode_logical_blocks)

DIRECT_CLI = ROOT / 'backend/fpkg-cli-direct/fpkg'
MAGIC = bytes.fromhex('02000000000000000b2a330100000000')
child = None

def stop_child():
    if child and child.poll() is None:
        os.killpg(child.pid, signal.SIGINT)
        try: child.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()

def emit(kind, **data):
    print(json.dumps(dict(event=kind, **data), ensure_ascii=False), flush=True)

def cancel(sig, frame):
    stop_child()
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, cancel)
signal.signal(signal.SIGINT, cancel)

class InnerImage:
    def __init__(self, source, view, name):
        self.source, self.view, self.name = source, view, name
    def exists(self): return True
    def is_file(self): return True
    def stat(self): return SimpleNamespace(st_size=self.view._size)
    def __str__(self): return str(self.source) + '!/' + self.name
    @contextlib.contextmanager
    def open(self, mode):
        if mode != 'rb': raise ValueError('Read-only source')
        self.view.seek(0)
        yield self.view

def safe_path(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or '\\' in name or '\x00' in name:
        raise ValueError('Unsafe path in container: ' + name)
    return p

@contextlib.contextmanager
def nested(source):
    opened = None
    if source.is_file():
        with source.open('rb') as f: header = f.read(16)
        if header == MAGIC:
            opened = open_inner_file_view(source)
    if not opened:
        yield None
        return
    view, handle, name = opened
    try:
        if view.read(16) != MAGIC:
            yield None
            return
        image = InnerImage(source, view, name)
        info = inspect_pfs_image(image, verify_payloads=False)
        # Some older dumps carry a stale collision resolver: the directory tree
        # and payloads are still readable, so keep the diagnostic and continue.
        fatal = [e for e in info.errors if not e.startswith('hash 0x') and not e.startswith('collision resolver')]
        if fatal: raise ValueError('; '.join(fatal[:5]))
        for path in list(info.file_inodes) + list(info.dir_inodes): safe_path(path)
        yield image, info
    finally:
        handle.close()

def read_entry(image, info, path, limit=2*1024*1024):
    inode = info.inodes[info.file_inodes[path]]
    if inode.logical_size > limit: raise ValueError('Metadata is too large')
    with image.open('rb') as f:
        return b''.join(iter_inode_logical_blocks(f, info.header, inode))

def details(image, info):
    params = [p for p in info.file_inodes if p == 'sce_sys/param.json' or p.endswith('/sce_sys/param.json')]
    if len(params) != 1: raise ValueError('The container must have exactly one sce_sys/param.json')
    name = params[0]
    base = name[:-len('sce_sys/param.json')]
    if base + 'eboot.bin' not in info.file_inodes: raise ValueError('eboot.bin is missing')
    meta = json.loads(read_entry(image, info, name).decode('utf-8-sig'))
    localized = meta.get('localizedParameters', {})
    title = localized.get('it-IT', localized.get(localized.get('defaultLanguage','en-US'),{})).get('titleName','Untitled')
    size = sum(info.inodes[n].logical_size for p,n in info.file_inodes.items() if p.startswith(base))
    icon_path = base + 'sce_sys/icon0.png'
    icon_b64 = ''
    if icon_path in info.file_inodes:
        try:
            icon_b64 = base64.b64encode(read_entry(image, info, icon_path, 8*1024*1024)).decode('ascii')
        except (ValueError, OSError):
            pass
    return dict(title=title, content_id=meta.get('contentId',''), title_id=meta.get('titleId',''),
                version=meta.get('contentVersion',''), package_type='Application / Game (APP)',
                image_mode='PLAINTEXT_NOAUTH', format='Nested PFS • streaming supported',
                files=len(info.file_inodes), bytes=size, base=base, icon_b64=icon_b64)

def run_cli(args, log=None, executable=DIRECT_CLI, cwd=None):
    global child
    child = subprocess.Popen([str(executable), *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors='replace', bufsize=1, start_new_session=True, cwd=cwd)
    lines=[]
    try:
        for line in child.stdout:
            line=line.rstrip()
            if line:
                lines.append(line)
                if log: log.write(line+'\n'); log.flush()
                emit('log', text=line)
        rc=child.wait()
        if rc: raise RuntimeError('FPKG engine: ' + '\n'.join(lines[-4:]))
        return '\n'.join(lines)
    finally:
        stop_child()
        child=None

def inspect(source):
    with nested(source) as result:
        if result:
            emit('metadata', **details(*result))
        else:
            if not DIRECT_CLI.exists():
                raise RuntimeError('Native fpkg-cli was not found in the app')
            run_cli(['inspect', str(source), '--lang','en'], executable=DIRECT_CLI, cwd=DIRECT_CLI.parent)
            emit('metadata', title=source.name, content_id='', format='Format handled by fpkg-cli',
                 version='', title_id='', package_type='Application / Game (APP)',
                 image_mode='PLAINTEXT_NOAUTH', files=0, bytes=0, icon_b64='')

def fingerprint(path):
    s=path.stat()
    return (s.st_size,s.st_mtime_ns)

def extract(image, info, dest, meta):
    total=meta['bytes'];done=0;last=0
    manifest={}
    base=meta['base']
    with image.open('rb') as f:
        for name,num in sorted(info.file_inodes.items()):
            if not name.startswith(base): continue
            relative=name[len(base):]
            safe_path(relative)
            if any(p.startswith('._') or p in ('.DS_Store','__MACOSX') for p in PurePosixPath(relative).parts):continue
            target=dest/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            inode=info.inodes[num];written=0;digest=hashlib.sha256()
            with target.open('xb') as out:
                for chunk in iter_inode_logical_blocks(f,info.header,inode):
                    out.write(chunk);digest.update(chunk);written+=len(chunk);done+=len(chunk)
                    if time.monotonic()-last>0.35:
                        emit('progress',text='Reading game',value=0.45*done/max(total,1),detail=f'{done/1e9:.2f} / {total/1e9:.2f} GB')
                        last=time.monotonic()
            if written != inode.logical_size: raise ValueError('Incomplete extracted file: '+relative)
            manifest[relative]=dict(bytes=written,sha256=digest.hexdigest())
    return manifest

def build(source, output, engine):
    if not output.is_dir(): raise ValueError('Choose an existing destination folder')
    if source.is_dir() and output.resolve().is_relative_to(source.resolve()):
        raise ValueError('The destination cannot be inside the source')
    original=fingerprint(source)
    job=Path(tempfile.mkdtemp(prefix='FPKG-',dir=output))
    success=False
    try:
        with (job/'build.log').open('w') as log:
            staging=job/'temporary';staging.mkdir()
            # fpkg-cli is the only packaging path. It accepts folders, .ffpfsc and .exfat.
            if engine == 'direct' and DIRECT_CLI.exists() and (source.is_dir() or source.suffix.lower() in {'.ffpfsc', '.exfat'}):
                emit('log', text='fpkg-cli: native build, Kraken level 7.')
                direct_out = job/'direct-output'; direct_out.mkdir()
                try:
                    # Patching is release-specific and must never modify the signed app bundle.
                    direct_home = staging/'fpkg-cli'; shutil.copytree(DIRECT_CLI.parent, direct_home)
                    direct_exec = direct_home/'fpkg'
                    run_cli(['patch'], log, executable=direct_exec, cwd=direct_home)
                    run_cli(['build','--source',str(source),'--out',str(direct_out),
                             '--temp-dir',str(staging/'direct-engine'),
                             '--kraken-backend','BuiltIn','--kraken-level','7'], log,
                            executable=direct_exec, cwd=direct_home)
                    packages=list(direct_out.glob('*.pkg'))
                    if len(packages) != 1: raise RuntimeError('fpkg-cli did not produce a single package')
                    emit('progress', text='Verification complete', value=0.9, detail='Checking the package written to disk')
                    success=True
                    emit('done', path=str(packages[0]), text='Package created and verified with fpkg-cli (Kraken 7)')
                    return
                except RuntimeError:
                    raise
            raise ValueError('Source format is not supported by the native backend: use a folder, .ffpfsc, or .exfat')
            prepared=source
            with nested(source) as result:
                if result:
                    image,info=result;meta=details(image,info)
                    emit('metadata',**meta)
                    needed_native=meta['bytes']*2.2+1024**3
                    needed_sdk=meta['bytes']*3.8+5*1024**3
                    free=shutil.disk_usage(job).free
                    if free<needed_native:
                        raise ValueError(f'Not enough space in the destination: the native engine needs about {needed_native/1e9:.1f} GB free')
                    if engine=='sdk' and free<needed_sdk:
                        emit('log',text=f'Not enough free space for Sony SDK temporary copies (estimated {needed_sdk/1e9:.1f} GB); switching automatically to the native engine, which needs about {needed_native/1e9:.1f} GB.')
                        engine='native'
                    prepared=staging/'game';prepared.mkdir()
                    manifest=extract(image,info,prepared,meta)
                    (job/'estrazione-sha256.json').write_text(json.dumps(manifest,indent=2))
            emit('progress',text='Creating package',value=0.48,detail='The engine also verifies the result structure')
            args=['build','--source',str(prepared),'--output',str(job),'--temp',str(staging/'engine'),
                  '--preset','fast','--full-verify','--sha256','--lang','en']
            if engine=='native':args+=['--no-sony-sdk']
            try:
                run_cli(args,log)
            except RuntimeError as exc:
                if engine=='sdk' and 'No space left on device' in str(exc):
                    emit('log',text='Sony SDK ran out of space while creating the intermediate image; retrying automatically with the native engine.')
                    for item in list(job.iterdir()):
                        if item.name in {'build.log','temporary'}: continue
                        if item.is_dir(): shutil.rmtree(item,ignore_errors=True)
                        else:
                            with contextlib.suppress(OSError): item.unlink()
                    args=[a for a in args if a not in {'--full-verify','--sha256'}]
                    args += ['--no-sony-sdk','--full-verify','--sha256']
                    run_cli(args,log)
                else:
                    raise
            packages=list(job.glob('*.pkg'))
            if len(packages)!=1:raise RuntimeError('The engine did not produce a single package')
            emit('progress',text='Verification complete',value=0.9,detail='Checking the package written to disk')
            run_cli(['verify',str(packages[0]),'--full','--sha256','--lang','en'],log)
            if fingerprint(source)!=original:raise RuntimeError('The source changed during conversion')
            success=True
            emit('done',path=str(packages[0]),text='Pacchetto creato e verificato')
    finally:
        # Only our unique staging directory is disposable. Keep packages and logs.
        shutil.rmtree(job/'temporary',ignore_errors=True)
        if not success:emit('log',text='Operation failed. Diagnostics saved in '+str(job))

if __name__=='__main__':
    try:
        command=sys.argv[1];source=Path(sys.argv[2]).resolve(strict=True)
        if command=='inspect':inspect(source)
        elif command=='build':build(source,Path(sys.argv[3]).resolve(strict=True),sys.argv[4])
        else:raise ValueError('Unknown command')
    except KeyboardInterrupt:
        emit('error',text='Operation canceled');sys.exit(130)
    except Exception as e:
        emit('error',text=str(e));sys.exit(1)
