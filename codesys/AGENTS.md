# Scope of development

Keep new deaerator source, exports, documentation, and validation artifacts
inside this codesys/ directory. Do not edit, replace, or delete the original
project, README, option files, or compilation caches outside this directory
without a separate explicit user request.

Keep ST and PLCopen XML exports consistent. Distinguish structural checks from
actual CODESYS compilation and simulation. Do not add or change alarm logic
until the user explicitly asks for it.

Use the existing isolated checkout; do not create a Git worktree unless asked.
Do not commit uploaded binary compilation metadata or PC archives by default.
