;;; early-init.el --- before any package faces load  -*- lexical-binding: t -*-

;; Same Termux wiring as your emacs-android repo's early-init.el and the
;; blog post (Install Emacs on Android): the org.gnu.emacs app shares the
;; Termux signature, so its packages ($PREFIX) are our external programs.

(setenv "PREFIX" "/data/data/com.termux/files/usr")

(defun conc-prefix (&rest path-parts)
  "Return path constructed from PREFIX environment variable and PATH-PARTS."
  (apply #'concat (getenv "PREFIX") path-parts))

(defvar termux-bin (conc-prefix "/bin"))

(setenv "PATH" (format "%s:%s" termux-bin (getenv "PATH")))
(push termux-bin exec-path)

;; Mobile-friendly startup: allocate GC slack, restore after init (init.el).
(setq gc-cons-threshold (* 50 1024 1024)
      gc-cons-percentage 0.6)

(provide 'early-init)
;;; early-init.el ends here
