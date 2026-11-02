"""Optional TrainerOS protocol v1 client. Python 3.10+, standard library only.

The wire contract, not this wrapper, is the integration boundary. No automatic
reconnect across profiles and no hidden launch, storage, or network simulation.
"""
import collections
import json
import os
from pathlib import Path
import select
import socket
import time
import uuid


class HostUnavailable(RuntimeError):
    pass


class HostError(RuntimeError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def default_endpoint():
    if os.environ.get("TRAINEROS_SDK_ENDPOINT"):
        return Path(os.environ["TRAINEROS_SDK_ENDPOINT"])
    base = (Path(os.environ["LOCALAPPDATA"]) if os.name == "nt"
            else Path(os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")))
    return base / "traineros/platform-v1/endpoint.json"


class Client:
    def __init__(self, app, endpoint=None, timeout=3.0):
        self._socket = None
        self._buffer = bytearray()
        self._events = collections.deque()
        self._sequence = 0
        self.timeout = timeout
        self.context = {}
        self.capabilities = {}
        try:
            path = Path(endpoint) if endpoint else default_endpoint()
            if path.stat().st_size > 65536:
                raise ValueError("Invalid endpoint")
            info = json.loads(path.read_text(encoding="utf-8"))
            if info.get("protocol") != 1 or info.get("host") != "127.0.0.1":
                raise ValueError("Unsupported endpoint")
            self._socket = socket.create_connection(("127.0.0.1", int(info["port"])), timeout)
            result = self.call("hello", protocol=1, token=info["token"], app=app)
            self.capabilities = result["capabilities"]
        except HostError:
            self.close()
            raise
        except (OSError, ValueError, KeyError, HostUnavailable) as exc:
            self.close()
            raise HostUnavailable("TrainerOS is not available at this endpoint") from exc

    def supports(self, name, version=1):
        return self.capabilities.get(name) == version

    def account(self):
        """Public server identity only; sign-in and credentials belong to the host."""
        return self.call("account.get")["account"]

    def select_home_widget(self, widget_id):
        """Select this installed app's Home contribution after an explicit user action.

        Requires ui.home.widget:1. No installation, launch or stale-context retry.
        """
        return self.call("home.widget.select", id=widget_id, revision=self.context["revision"])

    def play_open(self, ruleset_id):
        """Host owns credentials. Use timeout >=20 for backend calls."""
        return self.call("play.open", ruleset_id=ruleset_id)

    def play(self, action, payload=None, operation_id=None):
        """Persist operation_id BEFORE a mutation; reuse only for the exact same payload.

        A timeout means unknown delivery. Reconnect explicitly under the same
        player, reopen the ruleset and retry with that saved ID. No hidden retry.
        """
        return self.call("play."+action, payload=payload or {}, operation_id=operation_id or str(uuid.uuid4()))

    def board(self, mode="individual", kind="records", **page):
        return self.call("play.board", mode=mode, kind=kind, **page)

    def _receive(self, deadline):
        while b"\n" not in self._buffer:
            if not self._socket:
                raise HostUnavailable("TrainerOS connection closed")
            remaining = deadline - time.monotonic()
            try:
                if not select.select([self._socket], [], [], max(0.0, remaining))[0]:
                    return None
                chunk = self._socket.recv(65536)
            except OSError as exc:
                self.close()
                raise HostUnavailable("TrainerOS connection lost") from exc
            if not chunk:
                self.close()
                raise HostUnavailable("TrainerOS connection closed")
            self._buffer.extend(chunk)
            if len(self._buffer) > 262144:
                self.close()
                raise HostUnavailable("TrainerOS receive limit exceeded")
        line, _, rest = self._buffer.partition(b"\n")
        self._buffer = bytearray(rest)
        packet = json.loads(line)
        if "context" in packet:
            self.context = packet["context"]
        if "context" in packet.get("result", {}):
            self.context = packet["result"]["context"]
        return packet

    def call(self, method, **params):
        if not self._socket:
            raise HostUnavailable("TrainerOS connection closed")
        self._sequence += 1
        request_id = str(self._sequence)
        wire = (json.dumps({"id": request_id, "method": method, "params": params},
                           separators=(",", ":")) + "\n").encode("utf-8")
        if len(wire) > 65536:
            raise ValueError("Request exceeds 64 KiB")
        try:
            self._socket.sendall(wire)
        except OSError as exc:
            self.close()
            raise HostUnavailable("TrainerOS connection lost; delivery is unknown") from exc
        deadline = time.monotonic() + self.timeout
        while True:
            packet = self._receive(deadline)
            if packet is None:
                # Delivery is unknown. Do not retry a mutation automatically.
                self.close()
                raise HostUnavailable("TrainerOS request timed out; result is unknown")
            if "event" in packet:
                if len(self._events) >= 256:
                    self.close()
                    raise HostUnavailable("Consume events before issuing more requests")
                self._events.append(packet)
                continue
            if packet.get("id") != request_id:
                self.close()
                raise HostUnavailable("Unexpected response identity")
            if "error" in packet:
                raise HostError(packet["error"]["code"])
            return packet["result"]

    def subscribe(self):
        return self.call("context.subscribe")["context"]

    def avatar(self, subscribe=False):
        """Console-owned local avatar. GLB stays outside the game's installation.

        avatar_not_ready after subscribe still establishes the subscription;
        consume avatar.changed. Clear the visual on context.revoked/disconnect.
        """
        return self.call("avatar.subscribe" if subscribe else "avatar.get")["avatar"]

    def poll(self, timeout=0.0):
        """One event or None; call from the app event loop. Single-threaded client."""
        if self._events:
            return self._events.popleft()
        return self._receive(time.monotonic() + max(0.0, timeout))

    def widget(self, widget_id, title, text=""):
        return self.call("widget.put", id=widget_id, title=title, text=text,
                         revision=self.context.get("revision", ""))

    def close(self):
        if self._socket:
            self._socket.close()
            self._socket = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
