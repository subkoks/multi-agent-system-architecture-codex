#!/usr/bin/env python3
"""Offline installer checks: fake homes only; no real CLI or provider access."""

import os
from pathlib import Path
import subprocess
import tempfile


REPO = Path(__file__).resolve().parent.parent
NAMES = ("planner", "governor", "builder", "reviewer")
SKILLS = ("orchestrate", "closed-loop", "loop")


def snapshot(root):
    """Record entries without following symlinks or depending on mtimes."""
    result = {}
    for path in sorted(root.rglob("*")):
        key = str(path.relative_to(root))
        if path.is_symlink():
            result[key] = ("link", os.readlink(path))
        elif path.is_dir():
            result[key] = ("dir",)
        else:
            result[key] = ("file", path.read_bytes())
    return result


def run(env, script, args, status=0):
    result = subprocess.run(
        ["bash", str(REPO / "scripts" / script), *args], cwd=REPO,
        env=env, capture_output=True, text=True, timeout=30, check=False,
    )
    assert result.returncode == status, (
        f"{script} {args}: exit {result.returncode}, expected {status}\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    )
    return result


def main():
    with tempfile.TemporaryDirectory(prefix="codex-install-") as tmp:
        root = Path(tmp)
        home = root / "home with spaces"
        home.mkdir()
        bin_dir = root / "bin"
        bin_dir.mkdir()
        codex = bin_dir / "codex"
        codex.write_text("#!/bin/sh\nexit 0\n")
        codex.chmod(0o755)
        env = dict(os.environ, HOME=str(home), CODEX_HOME=str(home / ".codex"),
                   PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
        installer = "install-codex-local.sh"
        smoke = "smoke-test-codex.sh"

        # This is the workstation's canonical skill layout, not repo symlinks.
        for name in SKILLS:
            personal = home / ".agents/skills" / name
            personal.mkdir(parents=True)
            (personal / "SKILL.md").write_text(f"personal {name}\n")
            mirror = home / ".codex/skills" / name
            mirror.parent.mkdir(parents=True, exist_ok=True)
            mirror.symlink_to(personal, target_is_directory=True)
        agents = home / ".codex/agents"
        agents.mkdir()
        (agents / "planner.toml").write_text("prior planner\n")
        before = snapshot(home)

        preview = run(env, installer, ["--agents-only"])
        assert snapshot(home) == before, "dry-run changed fake home"
        assert str(home / ".agents/backups/codex-native-install-") in preview.stdout
        assert "/planner.toml" in preview.stdout
        assert "-> /planner.toml" not in preview.stdout

        # A late canonical skill collision must refuse before ANY earlier write.
        for args in ([], ["--apply"]):
            result = run(env, installer, args, status=1)
            assert "[REFUSE]" in result.stderr
            assert snapshot(home) == before, "full collision caused partial writes"

        # Also preflight the last agent before copying the first.
        (agents / "reviewer.toml").mkdir()
        collision = snapshot(home)
        run(env, installer, ["--agents-only", "--apply"], status=1)
        assert snapshot(home) == collision, "late agent collision caused partial writes"
        (agents / "reviewer.toml").rmdir()

        # Backup ancestry is also preflighted before an agents-only apply.
        backup_root = home / ".agents/backups"
        backup_root.write_text("collision\n")
        collision = snapshot(home)
        run(env, installer, ["--agents-only", "--apply"], status=1)
        assert snapshot(home) == collision, "backup collision caused partial writes"
        backup_root.unlink()

        skill_state = {key: value for key, value in before.items()
                       if "/skills" in key}
        run(env, installer, ["--agents-only", "--apply"])
        for name in NAMES:
            assert (agents / f"{name}.toml").read_bytes() == (
                REPO / ".codex/agents" / f"{name}.toml").read_bytes()
        installed = snapshot(home)
        assert {key: value for key, value in installed.items()
                if "/skills" in key} == skill_state
        run(env, smoke, ["--live", "--agents-only", "--quiet"])
        run(env, smoke, ["--agents-only"], status=2)
        full_smoke = run(env, smoke, ["--live", "--quiet"], status=1)
        assert "not pointed at repo" in full_smoke.stderr

        manifests = list((home / ".codex/install-manifests").glob("*.manifest"))
        assert len(manifests) == 1
        run(env, installer, ["--rollback", str(manifests[0])])
        assert (agents / "planner.toml").read_text() == "prior planner\n"
        for name in NAMES[1:]:
            assert not (agents / f"{name}.toml").exists()
        restored = snapshot(home)
        assert {key: value for key, value in restored.items()
                if "/skills" in key} == skill_state
        for key, value in before.items():
            assert restored[key] == value, f"rollback changed prior entry: {key}"

        # Full installation still supports a home without canonical directories,
        # including restoring a previously managed link after repointing it.
        full_home = root / "full home"
        full_home.mkdir()
        full_env = dict(env, HOME=str(full_home),
                        CODEX_HOME=str(full_home / ".codex"))
        old_link = full_home / ".agents/skills/loop"
        old_link.parent.mkdir(parents=True)
        old_link.symlink_to(root / "prior missing skill")
        full_before = snapshot(full_home)
        run(full_env, installer, [])
        assert snapshot(full_home) == full_before
        run(full_env, installer, ["--apply"])
        run(full_env, smoke, ["--live", "--quiet"])
        for base in (".codex/skills", ".agents/skills"):
            for name in SKILLS:
                assert os.readlink(full_home / base / name) == str(REPO / "skills" / name)
        full_manifests = list((full_home / ".codex/install-manifests").glob("*.manifest"))
        assert len(full_manifests) == 1
        run(full_env, installer, ["--rollback", str(full_manifests[0])])
        assert os.readlink(old_link) == str(root / "prior missing skill")
        for name in NAMES:
            assert not (full_home / ".codex/agents" / f"{name}.toml").exists()
        for base in (".codex/skills", ".agents/skills"):
            for name in SKILLS:
                path = full_home / base / name
                if path != old_link:
                    assert not path.exists() and not path.is_symlink()

    print("[PASS] offline installer: agents-only apply/rollback, unchanged skills, "
          "zero-write dry-run, collision preflight, scoped live verification")


if __name__ == "__main__":
    main()
