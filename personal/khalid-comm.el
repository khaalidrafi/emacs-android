;;; khalid-comm.el --- Telega for Android  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-comm.el (telega only; notmuch,
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

(provide 'khalid-comm)
;;; khalid-comm.el ends here
