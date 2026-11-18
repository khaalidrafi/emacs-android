# HUMANS.md — emacs-android

A guide for humans navigating and developing this codebase. Written
2026-11-18 per the org-wide rule that every agent-developed repo
carries one.

## What this is

The Owner's personal Emacs configuration: ONE init that runs on both
a Linux desktop and an Android phone (the `org.gnu.emacs` APK plus
Termux binaries, or the `emacshell` APK). Not a package — a config
with an opinionated loader.

Per the Owner's 2026-11-18 order, this repo is also where PERSONAL
stuff lives: the habit tracker (`loophabits`), the mail stack
(notmuch over IMAP, NOT Gnus), and other config that is his rather
than generic. The `emacshell` app repo stays free of personal
configuration.

## Mental model

Startup is two files plus a module directory:

- `early-init.el` — package system and GC settings before anything
  loads (Termux `$PREFIX` awareness).
- `init.el` — startup, UI, completion, editing; then loads the
  `personal/` modules.
- `personal/` — the modules that are the Owner's:

| File | What it carries |
|---|---|
| `khalid-org.el` | Org capture, agenda, file layout, org-docs, tel/dial helpers. |
| `khalid-comm.el` | telega (Telegram), lark-org (Lark), Discord via emacs-purple, and NOTMUCH over IMAP. |
| `khalid-llm.el` | gptel/GoModel and the agent-connect entry points. |
| `khalid-keybindings.el` | the leader keymap actually used (prelude-evil machinery, meow-light, vertico). |

The mail stack (khalid-comm.el, "NOTMUCH over IMAP" section) is three
pieces by design: mbsync (isync) pulls IMAP into `~/mail` Maildirs
(Termux: `pkg install mbsync notmuch`), notmuch indexes them, and the
`notmuch` use-package block reads/sends. Gnus is deliberately absent.

The config expects an interactive session and SIBLING CHECKOUTS on
`load-path` (`org-import`, `agent-org`, `org-activity`, `agent-team.el`,
`elwidget`, and the rest of this account's packages). That is why CI
does not boot it — a runner has neither a frame nor the siblings.

## What CI checks (and why not more)

Dependency-free, `make`-less: every tracked `.el` is byte-compiled
with `use-package` installed, and the job fails if any file produced
no `.elc`. Compilation catches the real config mistakes — wrong
arity, void variables, renamed functions — without a display or the
sibling repos. Warnings are reported but not fatal (a config
legitimately refers to packages a runner does not have).

## Invariants and gotchas

- One init for two machines: guard anything frame- or
  desktop-specific (`scroll-bar-mode` & friends are already guarded)
  so a headless load does not die.
- `load-prefer-newer t` is set in `init.el`; respect it — never pin a
  stale `.elc`.
- Personal config goes HERE, not into `emacshell` (Owner order
  2026-11-18). The split: APK-required code and patches live in
  emacshell; everything the Owner would also want on a desktop lives
  here.
- `.elc` files in `personal/` are build artifacts of CI.
- The package installs use the Android config law: `:vc` with a
  public GitHub pin (see README.org's install examples).

## Developing

- Edit `personal/*.el` for behavior, `init.el` for load order and UI.
- Byte-compile check locally: `emacs -Q --batch -L . -f
  batch-byte-compile <file>.el` (expect warnings for missing
  siblings, zero errors).
- Branch law: work lands on `ai/main` (the default branch). Pushes go
  to GitHub (`github` remote) and the self-hosted mirror (`origin`).
- After changing the mail stack, re-read the mbsync/notmuch pieces
  together — the three parts only work as a set.
