"""Drive the TV over ECP.  remote.py Down Select 3 Select 'text:yuanshen' Back
A bare number waits that many seconds; text:... types literal characters."""
import os, sys, time, urllib.parse, urllib.request

def roku_ip() -> str:
    """ROKU_IP from the environment, else from .env.local next to the scripts."""
    if os.environ.get("ROKU_IP"):
        return os.environ["ROKU_IP"]
    env = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".env.local")
    try:
        for line in open(env, encoding="utf-8"):
            if line.startswith("ROKU_IP="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    sys.exit("set ROKU_IP or create .env.local (see .env.example)")


ip = roku_ip()


def post(path: str) -> None:
    urllib.request.urlopen(urllib.request.Request(f"http://{ip}:8060/{path}", data=b"", method="POST"), timeout=5)


for arg in sys.argv[1:]:
    try:
        time.sleep(float(arg))
        continue
    except ValueError:
        pass
    if arg.startswith("text:"):
        for ch in arg[5:]:
            post("keypress/Lit_" + urllib.parse.quote(ch, safe=""))
            time.sleep(0.15)
    else:
        post("keypress/" + arg)
        time.sleep(0.35)
