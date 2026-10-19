---
title: Graphify Status
tags: [lumiere, graphify, provenance]
---

# Graphify status

Graphify generation was attempted for this repository but did not complete in the current environment.

- The `graphify.exe` launcher exists at `C:\Users\renzr\.local\bin\graphify.exe`.
- Running it fails with `uv trampoline failed to canonicalize script path`, indicating its recorded tool environment is unavailable.
- `graphifyy` is not installed in the available Python 3.14 environment.
- Installing it from PyPI failed because network access is unavailable (`WinError 10051`).

Therefore these Obsidian notes are a manually authored, source-linked architecture map. No generated `graph.json`, `GRAPH_REPORT.md`, or graph visualization is claimed. Once Graphify is available, run its full pipeline with Obsidian export to generate the structural graph and node-level vault; retain these overview notes as human-oriented navigation.
