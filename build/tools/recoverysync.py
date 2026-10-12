#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Explicitly select and sync manifest-known recovery dependencies."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="Exact repo-relative project paths")
    parser.add_argument("--device", help="Read recovery.dependencies or lineage.dependencies from this device directory")
    parser.add_argument("--check", action="store_true", help="Report missing checkouts without changing groups or using the network")
    args = parser.parse_args()
    top = Path(__file__).resolve().parents[4]
    config = top / ".repo/manifests.git/config"
    if not config.is_file():
        parser.error("Run in a repo-initialized recovery checkout")
    catalog = set(subprocess.check_output(
        ["repo", "list", "-a", "-g", "all", "-p"], cwd=top, text=True).splitlines())
    paths = set(args.paths)
    if args.device:
        device = (top / args.device).resolve()
        if not device.is_relative_to(top / "device"):
            parser.error("Device directory must be inside this checkout's device directory")
        files = [device / name for name in ("recovery.dependencies", "lineage.dependencies")]
        dependency_file = next((file for file in files if file.is_file()), None)
        if dependency_file is None:
            parser.error("Device has no recovery.dependencies or lineage.dependencies; supply project paths explicitly")
        try:
            dependencies = json.loads(dependency_file.read_text())
            if not isinstance(dependencies, list):
                raise ValueError("dependency metadata must be a list")
            for dependency in dependencies:
                path = dependency["target_path"]
                if not isinstance(path, str):
                    raise ValueError("target_path must be a string")
                paths.add(path)
        except (ValueError, KeyError, TypeError) as error:
            parser.error(f"Invalid device dependency metadata: {error}")
    if not paths:
        parser.error("Supply project paths or --device")
    unknown = paths - catalog
    if unknown:
        parser.error("Projects absent from manifest: " + ", ".join(sorted(unknown)) +
                     ". Add an explicit local manifest for a new device; sources are never guessed.")
    missing = sorted(path for path in paths if not (top / path / ".git").exists())
    if args.check:
        if missing:
            print("Missing recovery dependencies: " + " ".join(missing))
            print("Fetch explicitly: recoverysync " + " ".join(missing))
            return 1
        print("Selected recovery dependencies are checked out")
        return 0
    previous = subprocess.run(["git", "config", "--file", str(config), "--get", "manifest.groups"],
                              text=True, capture_output=True, check=False)
    if previous.returncode not in (0, 1):
        raise SystemExit(previous.stderr)
    groups = (previous.stdout.strip() or "default").split(",")
    for path in sorted(paths):
        group = "path:" + path
        if group not in groups:
            groups.append(group)
    subprocess.run(["git", "config", "--file", str(config), "manifest.groups", ",".join(groups)], check=True)
    # Keep explicit selections for later normal syncs; do not remove projects or
    # force dirty checkouts. The caller explicitly requested this network action.
    subprocess.run(["repo", "sync", "-c", "-j50", *sorted(paths)], cwd=top, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
