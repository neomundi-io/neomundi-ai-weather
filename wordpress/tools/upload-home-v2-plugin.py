"""Upload ai-weather-blocks-preview to neomundi.cloud via SFTP.

Same mechanism as upload-stage.py: shells out to the native `sftp`
binary in batch mode, authenticated however AW_SSH_USER@AW_SSH_HOST is
already trusted on this machine (agent or default identity — no secret
is read from this repo or from any environment variable other than the
host/user names).

Only ever PUTs the 6 files of plugins/ai-weather-blocks-preview into a
brand-new directory under wp-content/plugins/. Never touches
wp-content/themes, nor any other existing plugin.

Requires AW_SSH_USER and AW_SSH_HOST in the environment.
"""
import os, pathlib, subprocess, sys

base = pathlib.Path(__file__).resolve().parents[1]
source = base / 'plugins' / 'ai-weather-blocks-preview'
files = sorted(p for p in source.rglob('*') if p.is_file())
assert files, 'plugin source not found: ' + str(source)

target = '/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud/wp-content/plugins/ai-weather-blocks-preview'

dirs = set()
for f in files:
    rel = f.relative_to(source)
    for d in pathlib.PurePosixPath(rel.as_posix()).parents:
        if str(d) != '.':
            dirs.add(str(d))

lines = ['mkdir "' + target + '"']
lines += ['mkdir "' + target + '/' + d + '"' for d in sorted(dirs, key=lambda p: (p.count('/'), p))]
lines += [
    'put "' + f.as_posix() + '" "' + target + '/' + f.relative_to(source).as_posix() + '"'
    for f in files
]

cmd = [
    'sftp', '-F', 'NUL', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-P', '22', '-b', '-',
    os.environ['AW_SSH_USER'] + '@' + os.environ['AW_SSH_HOST'],
]
r = subprocess.run(cmd, input='\n'.join(lines) + '\n', text=True, capture_output=True)
if r.returncode:
    print(r.stdout[-3000:])
    print(r.stderr)
    sys.exit(r.returncode)

print(f'SFTP: {len(files)} files uploaded into a new plugins/ai-weather-blocks-preview directory.')
for f in files:
    print(' -', f.relative_to(source).as_posix())
