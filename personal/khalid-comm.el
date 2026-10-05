;;; khalid-comm.el --- Telega & Notmuch for Android  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-comm.el (telega and notmuch;
;; mu4e, libpurple stay on the PC).
;;
;; Differences from the PC, forced by the device:
;; - telega comes from MELPA (:ensure t), there is no Guix emacs-telega
;;   here; `telega-server-libs-prefix' points at Termux $PREFIX where
;;   tdlib/telega-server are installed (`pkg install telega').
;; - telega-lite is cloned from the Gitea on first use (use-package :vc);
;;   it holds the touch/weak-device tweaks.
;; - The PC's evil key snippets are omitted; meow's motion state on
;;   `telega-root-mode' (see khalid-keybindings.el) gives the j/k browsing.
;; - notmuch is configured for mail reading over the Termux notmuch binary.

;;; Code:

;; Common config between desktop and phone
(khalid/declare-prefix "x" "execute")

;; Lite tweaks: cloned from the Gitea by `:vc' when telega first loads
;; (README.org in the repo explains the no-fork design; the hook keeps
;; telega itself unloaded at startup).
(use-package telega-lite
  :vc (:url "https://git.khalidrafi.tech/telega-lite.git"
       :rev :newest)
  :after telega
  :commands (telega-lite-mode telega-touch-mode)
  :init
  (add-hook 'telega-load-hook #'telega-lite-mode))

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

;; Org link type for telega.  On the PC this comes from Guix's
;; emacs-telega-contrib; on the phone it exists only if the MELPA telega
;; build shipped it, so require it softly after org loads.
(with-eval-after-load 'org
  (require 'ol-telega nil t))

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
