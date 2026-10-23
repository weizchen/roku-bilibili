"""Tail the Roku BrightScript console (port 8085), reconnecting across reinstalls.

    proxy/.venv/bin/python scripts/console.py [seconds] > console.log
"""
import os, socket, sys, time

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
deadline = time.time() + float(sys.argv[1]) if len(sys.argv) > 1 else float("inf")
while time.time() < deadline:
    try:
        with socket.create_connection((ip, 8085), timeout=3) as s:
            s.settimeout(1)
            while time.time() < deadline:
                try:
                    data = s.recv(65536)
                except socket.timeout:
                    continue
                if not data:
                    break
                sys.stdout.write(data.decode("utf-8", "replace").replace("\r", ""))
                sys.stdout.flush()
    except OSError:
        time.sleep(0.5)
