#!/usr/bin/env python3
"""Linux installer lifecycle check against the real reviewed TrainerOS installer."""
import hashlib
import io
import json
import os
import socket
import subprocess
import threading
from pathlib import Path
import sys
import tarfile
import tempfile


def main():
    installer_dir, output = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(installer_dir))
    from installer import Store, validate_records
    record = json.loads((output / "home-companion-x86_64-record.json").read_text())
    validate_records([record])
    archive = output / record["url"].rsplit("/", 1)[1]
    with tempfile.TemporaryDirectory() as temporary:
        base = Path(temporary)
        os.environ["XDG_DATA_HOME"] = str(base / "desktop")
        store = Store(base / "crates")
        receipt = store.activate(archive, record, lambda *args: None, lambda: False)
        installed = store.root / "objects" / receipt["object"]
        assert (installed / "launch.py").stat().st_mode & 0o111
        assert json.loads((installed / "home-widgets.json").read_text())["app"] == "home-companion"
        # Execute the actual installed entry with the bundled shared SDK client.
        # Wire fixture checks the bridge handshake and explicit Home selection;
        # real host admission is tested separately by PlatformHostTests.
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            listener.settimeout(8)
            endpoint = base / "endpoint.json"
            endpoint.write_text(json.dumps(dict(protocol=1, host="127.0.0.1", port=listener.getsockname()[1], token="fixture")))
            packets = []
            def host():
                with listener.accept()[0] as client:
                    client.settimeout(8)
                    with client.makefile("rwb") as stream:
                        for result in ({"capabilities": {"ui.home.widget": 1}, "context": {"profile": "fixture", "revision": "7"}}, {"id": "pet"}):
                            request = json.loads(stream.readline())
                            packets.append(request)
                            stream.write((json.dumps({"id": request["id"], "result": result}) + "\n").encode())
                            stream.flush()
            worker = threading.Thread(target=host, daemon=True)
            worker.start()
            subprocess.run([str(installed / "launch.py")], env=dict(os.environ, TRAINEROS_SDK_ENDPOINT=str(endpoint)), check=True, timeout=10)
            worker.join(timeout=10)
            assert len(packets) == 2
            assert packets[0]["params"]["app"] == "home-companion"
            assert packets[1]["method"] == "home.widget.select"
            assert packets[1]["params"] == {"id": "pet", "revision": "7"}
        data = store.root / "data" / "home-companion" / "retained.txt"
        data.parent.mkdir(parents=True)
        data.write_text("retained care fixture")
        update = base / "update.tar.gz"
        with tarfile.open(archive) as source, tarfile.open(update, "w:gz") as target:
            for member in source.getmembers():
                target.addfile(member, source.extractfile(member))
            content = b"lifecycle update fixture\n"
            info = tarfile.TarInfo("update-fixture.txt")
            info.size = len(content)
            target.addfile(info, io.BytesIO(content))
        newer = dict(record, version="0.1.1", size=update.stat().st_size,
                     sha256=hashlib.sha256(update.read_bytes()).hexdigest())
        validate_records([newer])
        updated = store.activate(update, newer, lambda *args: None, lambda: False)
        assert updated["previousObject"] == receipt["object"]
        assert store.receipt("home-companion")["version"] == "0.1.1"
        store.remove("home-companion")
        assert store.receipt("home-companion") is None and data.read_text() == "retained care fixture"
        store.activate(archive, record, lambda *args: None, lambda: False)
        assert data.read_text() == "retained care fixture"
        assert store.receipt("home-companion")["version"] == "0.1.0"
    print("PASS: real installer install/update/remove/reinstall, launcher wire, manifest and retained data")


if __name__ == "__main__":
    main()
