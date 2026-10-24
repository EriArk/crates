"""Pin the optional Qt avatar consumer; ships code, never Trainer model assets."""
import argparse, hashlib, json, subprocess
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("sdk", type=Path, nargs="?")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    output = Path(__file__).parent / "avatar-sdk"
    output.mkdir(exist_ok=True)
    files = ["AvatarCards.h", "AvatarPortrait.qml", "AvatarPortraitScene.qml", "PlayerCard.qml"]
    digest = lambda data: hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()
    if args.verify:
        record=json.loads((output/"UPSTREAM.json").read_text(encoding="utf-8"))
        for name in files:
            if digest((output/name).read_bytes())!=record['sha256'][name]:
                raise SystemExit('SDK copy differs: '+name)
        print('Qt avatar SDK copies match',record['revision'])
        return
    if args.sdk is None: parser.error('Pass the TrainerOS SDK checkout')
    dirty = subprocess.check_output(["git", "-C", str(args.sdk), "status", "--porcelain", "--", "sdk/qt"], text=True)
    if dirty.strip(): parser.error('Commit official SDK changes first')
    hashes = {}
    for name in files:
        data = (args.sdk / "sdk/qt" / name).read_bytes().replace(b'\r\n',b'\n')
        (output / name).write_bytes(data)
        hashes[name] = digest(data)
    revision = subprocess.check_output(["git", "-C", str(args.sdk), "rev-parse", "HEAD"], text=True).strip()
    (output / "UPSTREAM.json").write_text(json.dumps({"repository":"https://github.com/EriArk/TrainerOS", "revision":revision, "normalization":"LF", "license":"GPL-3.0-or-later", "sha256":hashes},indent=2)+"\n",encoding="utf-8")

if __name__ == "__main__": main()
