;;; khalid-comm.el --- Telega, Lark, Discord & Notmuch for Android  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-comm.el (telega, lark-org,
;; notmuch and now Discord via emacs-purple; mu4e stays on the PC).
;;
;; Differences from the PC, forced by the device:
;; - telega is :vc-pinned below (no Guix emacs-telega here);
;;   `telega-server-libs-prefix' points at Termux $PREFIX, where tdlib
;;   rides `pkg install libtd' (1.8.69 ships include/td/telegram/
;;   td_json_client.h + lib/libtdjson.so -- verified against the
;;   aarch64 index 2026-11-05; there is NO `telega' package) and
;;   telega-server is built in Emacs with `M-x telega-server-build'.
;; - telega-org, the Org outline for the chat list, is :vc-cloned from
;;   its PUBLIC GitHub mirror (pinned 2c9c500, the Android-certification
;;   HEAD; code unchanged since the ORG-CHAT-STANDARD v1.1 sync) and
;;   opened with a command rather than a mode hook (see below).  The
;;   Gitea origin flaps (Radicle 500s), so nothing here points at it
;;   any more.
;; - lark-org rides the same law for Lark Messenger (Owner 2026-11-07
;;   #hq: "update emacs android with comms pkgs"): :vc-pinned from the
;;   PUBLIC GitHub mirror (f95e4ac, the v0.2 Android-compat law HEAD)
;;   and opened with commands.  Its backend is the Lark Open Platform
;;   REST API over url.el -- pure elisp, no daemon, no Termux build.
;;   One-time Lark app setup: `lark-org-app-id' + the app secret in
;;   auth-source (see the block below).
;; - PRIVATE repos (telega-lite, emacs-purple) cannot ride :vc (anon
;;   clones fail, CI included): they are cloned on demand into ~/comm by
;;   `khalid/clone-comm-extras' (needs the ~/.git-askpass credentials
;;   init.el already wires) and loaded only when the checkout exists.
;; - Discord rides along since 2026-11-04 (Owner: "They MUST be ready to
;;   use on Android Emacs with Termux").  The elim daemon and the
;;   purple-discord plugin are BUILT ON DEVICE per
;;   ~/comm/emacs-purple/USAGE-ANDROID.org -- Termux is bionic libc, PC
;;   binaries never load here.
;; - The PC's evil key snippets are omitted; meow's motion state on
;;   `telega-root-mode' (see khalid-keybindings.el) gives the j/k browsing.
;; - notmuch is configured for mail reading over the Termux notmuch binary.

;;; Code:

;; Common config between desktop and phone
(khalid/declare-prefix "x" "execute")

;; Guarded-clone loader for the PRIVATE comm repos (telega-lite,
;; emacs-purple): cloned on demand from the GitHub mirrors, loaded only
;; when the checkout already exists, so a fresh boot (and CI) never
;; touches the network for them and never fails on auth.

(defgroup khalid-comm nil
  "Telega, Discord and notmuch on Android (khalid-comm.el)."
  :group 'comm)

(defcustom khalid-comm-extras-dir (expand-file-name "~/comm")
  "Directory holding the private comm repos on the phone."
  :type 'directory
  :group 'khalid-comm)

(defun khalid/clone-comm-extras ()
  "Clone telega-lite and emacs-purple into `khalid-comm-extras-dir'.
One-time setup; needs the ~/.git-askpass credentials init.el wires.
After cloning emacs-purple, build the daemon per its USAGE-ANDROID.org."
  (interactive)
  (dolist (spec '(("telega-lite" . "https://github.com/khaalidrafi/telega-lite.git")
                  ("emacs-purple" . "https://github.com/khaalidrafi/emacs-purple.git")))
    (let ((dir (expand-file-name (car spec) khalid-comm-extras-dir)))
      (if (file-directory-p dir)
          (message "%s already present" dir)
        (make-directory khalid-comm-extras-dir t)
        (call-process "git" nil "*khalid-clone*" t "clone" (cdr spec) dir)
        (message "cloned %s" dir)))))

;; telega-lite: touch/weak-device tweaks (README.org explains the
;; no-fork design; the hook keeps telega itself unloaded at startup).
(let ((lite-dir (expand-file-name "telega-lite" khalid-comm-extras-dir)))
  (when (file-directory-p lite-dir)
    (add-to-list 'load-path lite-dir)
    (autoload 'telega-lite-mode "telega-lite" nil t)
    (autoload 'telega-touch-mode "telega-lite" nil t)
    (add-hook 'telega-load-hook #'telega-lite-mode)))

(use-package telega
  ;; Pinned to the newest commit whose `telega-tdlib-min-version' (1.8.44)
  ;; still fits Termux's libtd (currently 1.8.50).  The next commit,
  ;; "Support for TDLib 1.8.52" (952841ca...), raises the minimum to 1.8.52,
  ;; which 1.8.50 fails; newer commits need 1.8.66+.  Bump this revision
  ;; only when `pkg upgrade libtd' lands a libtd new enough.  Check the
  ;; live minimum at:
  ;;   curl -s https://raw.githubusercontent.com/zevlg/telega.el/master/telega.el \
  ;;     | grep telega-tdlib-min-version
  :vc (:url "https://github.com/zevlg/telega.el"
       :rev "ff06f58364375c96477561f265e3dbf55a8ad231")
  :commands (telega)
  :init
  ;; No images/emoji bitmaps on the phone: much faster rendering over
  ;; mobile data (PC khalid-comm.el + ~/emacs-android both do this).
  (setq telega-use-images nil)
  (setq telega-emoji-use-images nil)

  (defun khalid/telega-open-khalids-shell (arg)
    (interactive "P")
    (unless (telega-server-live-p)
      (telega 1)
      (sleep-for 2))
    (telega-chat-with (telega-chat-get (if arg "-1002534038305" ;; open english channel
                                         "-1002317220500"))))

  (defun khalid/telega-open-freshorama ()
    (interactive)
    (unless (telega-server-live-p)
      (telega 1)
      (sleep-for 2))
    (if (get-buffer "◀[Freshorama Website]")
        (switch-to-buffer "◀[Freshorama Website]")
      (telega-chat-with (telega-chat-get -1003745676900))))

  (khalid/set-leader-keys
   "xt" 'telega
   "tf" 'khalid/telega-open-freshorama
   "tk" 'khalid/telega-open-khalids-shell)

  :config
  ;; tdlib + telega-server live in Termux's $PREFIX (set in early-init.el),
  ;; same as ~/emacs-android's `(setq telega-server-libs-prefix (get-prefix))'.
  (setq telega-server-libs-prefix (getenv "PREFIX"))

  (setq telega-symbol-heavy-checkmark "󰄰")
  (setq telega-database-dir (expand-file-name "~/telega-data/"))
  (setq telega-accounts (list
                         (list "usernameofkhalid" 'telega-database-dir telega-database-dir)
                         (list "account2" 'telega-database-dir
                               (expand-file-name "account2" telega-database-dir))))

  (setq telega-chat-bidi-display-reordering t)

  (setopt telega-chat-input-markups '("markdown2" "org"))

  ;; MELPA's telega keeps the adblock minor mode in contrib/, which its
  ;; autoloads do not cover (Guix's emacs-telega does), so require it.
  (require 'telega-adblock)
  (telega-adblock-mode 1))

;; The Org chat list: same no-fork shape, but :vc-cloned from the PUBLIC
;; GitHub mirror and pinned (Gitea flaps; CI must stay reproducible).
;; It is command-driven, not a mode hook: `telega-org-list' draws the
;; root buffer as an Org outline.  Loading the file is what installs its
;; own `with-eval-after-load' telega update hooks, so the autoload is
;; the only setup needed here; leader "tt" (telega group, next to
;; "tf"/"tk") opens it and "tn" jumps to the next unread chat.
(use-package telega-org
  :vc (:url "https://github.com/khaalidrafi/telega-org.git"
       :rev "2c9c500a2aade9fe4f106edebc786c390c614145")
  :after telega
  :commands (telega-org-list telega-org-jump-to-unread)
  :init
  (khalid/set-leader-keys
   "tt" 'telega-org-list
   "tn" 'telega-org-jump-to-unread))

;; Lark Messenger: the same Org outline law (ORG-CHAT-STANDARD v1.1)
;; with its own backend -- the Lark Open Platform REST API over
;; url.el.  Pure elisp, so unlike Discord it needs NO daemon and NO
;; Termux build, and like telega-org it rides the public :vc pin
;; (f95e4ac carries the Android-compat law; see README * Android /
;; touch).  One-time setup, per README * Setup: create a Lark app with
;; im:message scopes, set `lark-org-app-id', and store the app secret
;; in auth-source:
;;   machine lark-org login app-secret password <secret>
;; The secret and the cached tenant token stay in memory only.  Until
;; the app id is set, `lark-org' fails loudly at the first call -- it
;; never half-opens a broken list.  Leader "l" group: "ll" opens the
;; chat list, "ln" jumps to the first unread entry (list or view); the
;; list's own verbs (RET/g/j/n/p/q + tap) come with the package.
(use-package lark-org
  :vc (:url "https://github.com/khaalidrafi/lark-org.git"
       :rev "f95e4acc596140818c41096a9ccfd10433b14f22")
  :commands (lark-org lark-org-jump-unread)
  :init
  (khalid/declare-prefix "l" "lark")
  (khalid/set-leader-keys
   "ll" 'lark-org
   "ln" 'lark-org-jump-unread))

;; Org link type for telega.  On the PC this comes from Guix's
;; emacs-telega-contrib; on the phone it exists only if the MELPA telega
;; build shipped it, so require it softly after org loads.
(with-eval-after-load 'org
  (require 'ol-telega nil t))

;; ====================
;; DISCORD via emacs-purple (libpurple elim daemon, built on device)
;; ====================
;; One-time, in Termux (see ~/comm/emacs-purple/USAGE-ANDROID.org):
;;   create ~/.git-askpass (must print the PAT when called with "Password")
;;   M-x khalid/clone-comm-extras RET           ; clones the private repos
;;   cd ~/comm/emacs-purple && bash scripts/bootstrap-termux.sh
;;     (libpurple is NOT a Termux package -- the bootstrap builds it from
;;      source, then the purple-discord plugin + the elim daemon)
;; The elisp side below loads only when the checkout exists.  The daemon
;; path points at the clone so `libpurple-start' finds the binary.
(let ((purple-dir (expand-file-name "emacs-purple" khalid-comm-extras-dir)))
  (when (file-directory-p purple-dir)
    (add-to-list 'load-path purple-dir)
    (setq libpurple-daemon-path (expand-file-name "elim" purple-dir))
    (autoload 'libpurple-start "libpurple-discord" nil t)
    (autoload 'libpurple-stop "libpurple-discord" nil t)
    (autoload 'libpurple-add-account "libpurple-discord" nil t)
    (autoload 'libpurple-connect "libpurple-discord" nil t)
    (autoload 'libpurple-disconnect "libpurple-discord" nil t)
    (autoload 'libpurple-send-message "libpurple-discord" nil t)
    (autoload 'libpurple-list-accounts "libpurple-discord" nil t)
    (autoload 'libpurple-show-chat-buffer "libpurple-discord" nil t)
    (autoload 'emacs-purple-org-render "emacs-purple-org" nil t)
    (autoload 'emacs-purple-org-view-render "emacs-purple-org" nil t)
    (autoload 'emacs-purple-org-jump-unread "emacs-purple-org" nil t)
    (khalid/declare-prefix "d" "discord")
    (khalid/set-leader-keys
     "dd" 'libpurple-start
     "dc" 'libpurple-connect
     "dm" 'libpurple-send-message
     "dl" 'emacs-purple-org-render
     "dv" 'emacs-purple-org-view-render
     "dn" 'emacs-purple-org-jump-unread
     "db" 'libpurple-show-chat-buffer)))

;; ====================
;; NOTMUCH (Android email client)
;; ====================
(use-package notmuch
  :commands (notmuch notmuch-mua-new-mail)
  :init
  (khalid/declare-prefix "m" "mail")
  (khalid/set-leader-keys
   "mm" 'notmuch
   "mc" 'notmuch-mua-new-mail
   "ms" 'notmuch-search
   "mf" 'notmuch-refresh-this-buffer)
  :config
  (setq notmuch-search-oldest-first nil)
  (with-eval-after-load 'org
    (require 'ol-notmuch nil t)))

(provide 'khalid-comm)
;;; khalid-comm.el ends here
