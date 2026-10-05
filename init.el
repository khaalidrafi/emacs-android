;;; init.el --- Android Emacs config, light port of the PC prelude  -*- lexical-binding: t; -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Commentary:
;;
;; Minimal, blazing-fast Emacs for the phone (org.gnu.emacs app + Termux
;; binaries), focused on Org, Telega, Gptel (GoModel backend) and
;; agent-connect.  Structure mirrors your PC setup so usage feels familiar:
;;
;;   early-init.el                      <- Termux $PREFIX + GC slack
;;                                        (same as ~/emacs-android/early-init.el)
;;   init.el                            <- this file: barebones Android bits
;;                                        (from ~/emacs-android/barebones.el &
;;                                        khalid-common.el) + module loader
;;   personal/khalid-keybindings.el     <- prelude-evil.el leader machinery +
;;                                        khalid-meow.el (light) + vertico
;;   personal/khalid-org.el             <- khalid-org.el (Org + org-docs, no
;;                                        GTD layer) + tel/dial helpers
;;   personal/khalid-comm.el            <- khalid-comm.el telega (trimmed)
;;   personal/khalid-llm.el             <- khalid-llm.el gptel/GoModel +
;;                                        agent-connect client
;;
;; Everything heavy or PC-only (lsp, notmuch, mu4e, org-roam, eaf,
;; agent-shell, ...) is left out.

;;; Code:

(setq load-prefer-newer t)

;; ---------------------------------------------------------------------------
;; 1. Barebones Android setup (~/emacs-android/barebones.el, verbatim ideas)
;; ---------------------------------------------------------------------------

;; Packages that read raw key events (meow!) need text conversion off, or
;; the on-screen keyboard eats their bindings.
(setq overriding-text-conversion-style nil)
(setq touch-screen-display-keyboard t
      touch-screen-preview-select t
      ;; Undefined file types open as text, not fundamental.
      )
(setq-default major-mode 'text-mode)

;; Bars for touch use: modifier buttons near the thumb, no menu/scroll bar.
(when (fboundp 'modifier-bar-mode)
  (tool-bar-mode 1)
  (setopt tool-bar-position 'bottom)
  (modifier-bar-mode 1))
(menu-bar-mode -1)
(scroll-bar-mode -1)

;; Wrapped long lines stay readable on a narrow screen.
(global-visual-line-mode 1)
(global-visual-wrap-prefix-mode 1)

(recentf-mode 1)
(unless noninteractive
  (server-start))                ;; open files from Android share menu

;; Fonts: put .ttf files in ~/fonts (see the blog post), then here.
(when (display-graphic-p)
  (set-frame-font "JetBrains Mono")
  ;; Symbol/emoji fallbacks telega and Org need.
  (dolist (font '("Noto Sans Arabic" "Noto Sans Bengali"))
    (set-fontset-font "fontset-default" nil font nil 'prepend))
  (set-fontset-font t 'unicode "Symbols Nerd Font Mono" nil 'prepend)
  (set-fontset-font t 'symbol "Symbola" nil 'prepend)
  (set-fontset-font t 'emoji "Noto Color Emoji" nil 'prepend)
  (setq use-default-font-for-symbols nil))

;; Termux-side tooling: fish shell, git askpass, emacsclient as $EDITOR.
(when (eq system-type 'android)
  (let ((fish (conc-prefix "/bin/fish")))
    (when (file-exists-p fish)
      (setq shell-file-name fish)))
  (setenv "GIT_ASKPASS" (concat (getenv "HOME") "/.git-askpass"))
  (setenv "EDITOR" (conc-prefix "/bin/emacsclient -c"))
  (setenv "LD_PRELOAD" "$PREFIX/lib/libtermux-exec.so" t)
  (when (file-directory-p (expand-file-name "~/info"))
    (add-to-list 'Info-directory-list (expand-file-name "~/info"))))

;; ---------------------------------------------------------------------------
;; 2. Performance: restore a small heap after startup (pairs early-init.el)
;; ---------------------------------------------------------------------------
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 8 1024 1024)
                  gc-cons-percentage 0.1)))

;; ---------------------------------------------------------------------------
;; 3. Package system
;; ---------------------------------------------------------------------------
(require 'package)
(setq package-enable-at-startup nil
      package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)

;; Bootstrap use-package.  Install it from ELPA when it is not installed
;; yet -- and BEFORE any require: the ELPA copy (2.4.6) supports the `:vc'
;; keyword natively (`use-package-handler/:vc', built on the Emacs-29+
;; core `package-vc'), while some builds (Termux's) only ship an older
;; bundled copy without it.  `package-install' puts the new package first
;; on `load-path', so the ELPA version is the one that gets required.
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; ---------------------------------------------------------------------------
;; 4. Look & identity
;; ---------------------------------------------------------------------------
(setq inhibit-startup-screen t
      initial-scratch-message nil
      use-dialog-box nil
      confirm-kill-emacs #'y-or-n-p   ;; never die on a stray quit (khalid.el)
      help-window-select t
      large-file-warning-threshold 100000000)

(setopt user-full-name "Khalid Rafi")
(setopt user-mail-address "khaalidrafi@gmail.com")

;; M-x customize writes here, keeping init.el clean (PC: custom-android.el).
(setopt custom-file (expand-file-name "custom-android.el" user-emacs-directory))

;; Same theme logic as the PC khalid-early.el: rich display -> light
;; tritanopia modus, plain TTY -> dark modus.  Tritanopia needs Emacs 30.
(add-hook 'emacs-startup-hook
          (lambda ()
            (load-theme (if (and (>= emacs-major-version 30)
                                 (or (display-graphic-p)
                                     (string= (getenv "TERM_PROGRAM") "bcon")))
                            'modus-operandi-tritanopia
                          'modus-vivendi)
                        t)))

;; ---------------------------------------------------------------------------
;; 5. Personal modules (familiar keybindings + the four focus areas)
;; ---------------------------------------------------------------------------
(defvar khalid-android-personal-dir
    (expand-file-name "personal" (file-name-directory (or load-file-name buffer-file-name)))
  "Directory holding the Android personal config files.")

(dolist (module '(khalid-keybindings khalid-org khalid-comm khalid-llm))
  (load (expand-file-name (symbol-name module) khalid-android-personal-dir) t))

;; No `initial-buffer-choice' here: on the PC it opens the GTD "d" custom
;; agenda command, and the GTD layer is not part of this config.  With
;; `inhibit-startup-screen' the phone opens the ordinary startup buffer and
;; Org stays unloaded until you type C-c o w / C-c o z.

(provide 'init)
;;; init.el ends here
