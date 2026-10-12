#!/usr/bin/env python3
"""Offline CLI regression checks using disposable copies of repository contracts."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


REPO = Path(__file__).resolve().parent.parent


def run(fixture, env, script, args):
    return subprocess.run(
        ["bash", str(fixture / "scripts" / script), *args],
        cwd=fixture,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def expect(result, status, context):
    assert result.returncode == status, (
        f"{context}: expected exit {status}, got {result.returncode}\n"
        f"stdout: {result.stdout!r}\nstderr: {result.stderr!r}"
    )


def main():
    with tempfile.TemporaryDirectory(prefix="codex-quiet-") as tmp:
        root = Path(tmp)
        fixture = root / "repo with spaces"
        fixture.mkdir()
        # Copy only public contract inputs, preserving relative discovery links.
        for directory in ("skills", ".agents/skills", ".codex/agents"):
            shutil.copytree(REPO / directory, fixture / directory, symlinks=True)
        shutil.copy2(REPO / ".codex/config.toml", fixture / ".codex/config.toml")
        shutil.copy2(REPO / "AGENTS.md", fixture / "AGENTS.md")
        (fixture / "scripts").mkdir()
        scripts = {
            "smoke-test-codex.sh": (
                ["--repo"], "=== Codex-native smoke test ===",
                "[DONE] Codex-native smoke checks passed.",
            ),
            "eval-skill-smoke.sh": (
                [], "=== Skill contract smoke ===", "[DONE] Skill contracts intact.",
            ),
        }
        for script in scripts:
            shutil.copy2(REPO / "scripts" / script, fixture / "scripts" / script)

        bin_dir = root / "bin"
        bin_dir.mkdir()
        codex = bin_dir / "codex"
        codex.write_text("#!/bin/sh\nexit 0\n")
        codex.chmod(0o755)
        home = root / "home"
        home.mkdir()
        env = dict(os.environ, PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
                   HOME=str(home), CODEX_HOME=str(home / ".codex"))

        for script, (args, banner, done) in scripts.items():
            result = run(fixture, env, script, args)
            expect(result, 0, f"{script} normal success")
            assert banner in result.stdout and "[ OK ]" in result.stdout
            assert done in result.stdout and not result.stderr
            for quiet in ("--quiet", "-q"):
                result = run(fixture, env, script, [*args, quiet])
                expect(result, 0, f"{script} {quiet} success")
                assert not result.stdout and not result.stderr
            for mode in ([], ["--quiet"], ["-q"]):
                result = run(fixture, env, script, [*args, *mode, "--invalid"])
                expect(result, 2, f"{script} {mode} invalid option")
                assert not result.stdout
                assert result.stderr == "[ERR ] unknown option: --invalid\n"

        # Multiple independent failures must all be reported, including the CLI check.
        for skill in ("loop", "orchestrate"):
            (fixture / ".agents/skills" / skill).unlink()
        codex.write_text("#!/bin/sh\nexit 1\n")
        expected_smoke = [
            "[FAIL] .agents/skills/orchestrate missing or does not resolve",
            "[FAIL] .agents/skills/loop missing or does not resolve",
            "[FAIL] codex --strict-config rejected project",
        ]
        # A missing skill exercises both the file check and every dependent contract.
        expected_skill = [
            "[FAIL] missing skills/loop/SKILL.md",
            "[FAIL] loop: dynamic mode (pattern: dynamic)",
            "[FAIL] loop: sentinel pattern (pattern: AGENT_LOOP)",
            "[FAIL] loop: expiry/stop rule (pattern: Expiry and stop conditions)",
        ]
        for script, expected in (
            ("smoke-test-codex.sh", expected_smoke),
            ("eval-skill-smoke.sh", expected_skill),
        ):
            if script == "eval-skill-smoke.sh":
                (fixture / "skills/loop/SKILL.md").unlink()
            args = scripts[script][0]
            for mode in ([], ["--quiet"], ["-q"]):
                result = run(fixture, env, script, [*args, *mode])
                expect(result, 1, f"{script} {mode} multiple failures")
                assert result.stderr.splitlines() == expected, result.stderr
                if mode:
                    assert not result.stdout, result.stdout
                else:
                    assert scripts[script][1] in result.stdout
                    assert "[ OK ]" in result.stdout
                    assert "[FAIL] One or more" in result.stdout

    print("[PASS] offline quiet diagnostics: success, multiple failures, normal output, invalid options")


if __name__ == "__main__":
    main()
