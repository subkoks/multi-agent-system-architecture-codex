#!/usr/bin/env python3
"""Validate repo startup settings with Codex in an isolated, trusted fixture."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


PROJECT_CONFIG = Path(__file__).resolve().parent.parent / ".codex/config.toml"
UNKNOWN_KEY = "invalid_key_for_codex_config_probe"


def main():
    codex = shutil.which("codex")
    if not codex:
        sys.exit("[FAIL] Codex CLI is required for the native startup-config probe")

    with tempfile.TemporaryDirectory(prefix="codex-config-") as directory:
        root = Path(directory).resolve()
        home = root / "home"
        codex_home = home / ".codex"
        codex_home.mkdir(parents=True)
        project = root / "project"
        config_dir = project / ".codex"
        config_dir.mkdir(parents=True)
        config = config_dir / "config.toml"
        (codex_home / "config.toml").write_text(
            'project_root_markers = [".codex"]\n'
            f"[projects.{json.dumps(str(project))}]\n"
            'trust_level = "trusted"\n',
            encoding="utf-8",
        )
        canonical = PROJECT_CONFIG.read_text(encoding="utf-8")
        env = {"HOME": str(home), "CODEX_HOME": str(codex_home), "PATH": os.environ["PATH"]}
        command = [codex, "app-server", "--strict-config", "--print-startup-config"]

        config.write_text(canonical, encoding="utf-8")
        valid = subprocess.run(
            command, cwd=project, env=env, capture_output=True, text=True, timeout=15
        )
        if valid.returncode != 0:
            sys.exit(f"[FAIL] Codex startup rejected the repository config\n{valid.stdout}{valid.stderr}")
        try:
            startup = json.loads(valid.stdout)
        except json.JSONDecodeError:
            sys.exit("[FAIL] Codex startup did not return a JSON result")
        if not isinstance(startup, dict) or "error" in startup:
            sys.exit(f"[FAIL] unexpected startup response: {valid.stdout}")

        config.write_text(f"{UNKNOWN_KEY} = true\n{canonical}", encoding="utf-8")
        invalid = subprocess.run(
            command, cwd=project, env=env, capture_output=True, text=True, timeout=15
        )
        if invalid.returncode == 0 or UNKNOWN_KEY not in invalid.stdout + invalid.stderr:
            sys.exit("[FAIL] strict Codex startup did not reject the unknown project key")

    print("[PASS] native Codex startup accepted the repository config and rejected an unknown key")


if __name__ == "__main__":
    main()
