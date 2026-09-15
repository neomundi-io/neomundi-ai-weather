"""Run reviewed staging scripts through SSH stdin; no credentials stored."""
import base64, os, pathlib, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
SSH = ['ssh', '-F', 'NUL', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=20', '-p', '22', os.environ['AW_SSH_USER']+'@'+os.environ['AW_SSH_HOST']]
ROOT = '/home/clients/85f40bb325280e979ad0b9d01cc5b8a6/sites/neomundi.cloud'
script = (HERE / sys.argv[1]).read_bytes()
script = script.replace(b'@@MANIFEST_BASE64@@',base64.b64encode((HERE.parent/'validation/DEPLOYMENT-INVENTORY.json').read_bytes()))
interpreter = 'python3' if sys.argv[1].endswith('.py') else 'php'
result = subprocess.run(SSH + ['cd ' + ROOT + ' && ' + interpreter], input=script, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
sys.stdout.buffer.write(result.stdout)
sys.stderr.buffer.write(result.stderr)
sys.exit(result.returncode)
