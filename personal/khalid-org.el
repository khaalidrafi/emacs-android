;;; khalid-org.el --- Org for Android  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-org.el with the GTD layer taken
;; out: no capture templates, no custom agenda commands, no ~/org/gtd/
;; agenda-file list.  What remains is plain Org behaviour, the org-docs
;; reader, and the Android-only bits (tel: dialing, org-contacts helpers).
;; Also still dropped as before (heavy or PC-only): org-roam,
;; org-pomodoro, org-alert/habit-stats, activitywatch views, the "c"
;; contacts capture template, org-appear.

;;; Code:

;; ====================
;; KEYBINDINGS
;; ====================

(defun khalid/org-agenda-find-file ()
  "Find one of the `org-agenda-files'."
  (interactive)
  (find-file (completing-read "Find Org agenda file: " org-agenda-files nil t)))

(defun khalid/org-keys ()
  "Org leader keys kept from the PC: clocking, agenda, headings.
The GTD entry points (oF/oG capture+gtd files, oC/oT capture, oa/oA/oW
custom agenda commands) are gone with the GTD layer."
  (khalid/declare-prefix "o" "Org")
  (khalid/declare-prefix "oc" "clocks/contacts")

  (khalid/set-leader-keys
   "oc" 'org-clock-cancel
   "od" 'org-clock-display
   "oe" 'org-clock-modify-effort-estimate
   "og" 'org-clock-goto
   "oi" 'org-clock-in
   "ol" 'org-clock-in-last
   "oo" 'org-clock-out
   "or" 'org-clock-report
   "ov" 'org-resolve-clocks
   "of" 'khalid/org-agenda-find-file
   "oh" 'org-goto
   "ow" 'org-agenda-list
   "oz" 'org-agenda))

;; ====================
;; ORG
;; ====================

(use-package org
  :ensure nil
  :custom
  (org-directory "~/org")
  ;; Same choices as the PC (khalid-org.el):
  (org-agenda-start-on-weekday 6)          ;; week starts Friday
  (org-agenda-weekend-days '(5))
  (org-hide-emphasis-markers t)
  (org-use-property-inheritance '("effort" "category"))
  (org-log-into-drawer t)
  ;; One window: the phone screen has no room for a split agenda.
  (org-agenda-window-setup 'only-window)
  (org-agenda-sorting-strategy
   '((agenda time-up urgency-down category-keep)
     (todo urgency-down category-keep) (tags urgency-down category-keep)
     (search category-keep)))
  :config
  (setopt org-refile-targets '((org-agenda-files :regexp . "*")))
  (setq org-archive-location (concat org-directory "/archive.org::* From %s"))
  (keymap-set org-mode-map "C-<up>" 'org-shiftup)
  (keymap-set org-mode-map "C-<down>" 'org-shiftdown)
  (khalid/org-keys))

;; ====================
;; ORG-DOCS (local packages -> git.khalidrafi.tech, cloned by :vc)
;; ====================

;; org-import is an org-docs dependency the PC loads from ~/org-import/;
;; the phone has no local copy, so :vc clones it from the Gitea.  Its own
;; deps (plz, dash, s) come from ELPA/MELPA automatically.
(use-package org-import
  :vc (:url "https://git.khalidrafi.tech/org-import.git"
       :rev :newest)
  :after org
  :commands (org-import-markdown-as-org org-import-markdown-to-org))

;; Offline documentation reader (docs live under `org-docs-dir', same
;; ~/docs/ tree the PC uses; import commands are network-heavy, so the
;; reading keys below are what matters on the phone).  Keys mirror the
;; PC's "d..." leader set (khalid-org.el `use-package org-docs').
;;
;; `:after org', NOT `:after org-import': org-docs only reads org-import's
;; dynamic variables and calls its commands through autoloads (see the
;; "not required" note in org-docs.el), so nothing loads org-import at
;; startup.  Depending on it would defer this whole block -- including the
;; :init leader keys -- and C-c d* would stay unbound.
(use-package org-docs
  :vc (:url "https://git.khalidrafi.tech/org-docs.git"
       :rev :newest)
  :after org
  :commands (org-docs-open org-docs-search org-docs-search-current-doc
             org-docs-find-file org-docs-find-file-current-doc
             org-docs-recentf org-docs-current-doc-recentf
             org-docs-doc-recentf org-docs-find-last-doc-file
             org-docs-import-devdocs org-docs-browse-source-url
             org-docs-update-id-locations)
  :custom
  (org-docs-dir "~/docs/")
  ;; org-docs calls these as `(funcall cmd doc-dir)', so bind the dir and
  ;; ask for the pattern -- built-in replacements for consult-ripgrep/
  ;; consult-fd (Consult dropped as bloat).
  (org-docs-search-command
   (lambda (dir) (rgrep (read-string "Regex to search in docs: ") dir)))
  (org-docs-find-file-command
   (lambda (dir) (find-name-dired (read-string "File pattern: ") dir)))
  :init
  (khalid/declare-prefix "d" "docs")
  (khalid/set-leader-keys
   "dO" 'devdocs-browser-open
   "do" 'org-docs-open
   "ds" 'org-docs-search
   "dS" 'org-docs-search-current-doc
   "df" 'org-docs-find-file
   "dF" 'org-docs-find-file-current-doc
   "dr" 'org-docs-recentf
   "dR" 'org-docs-current-doc-recentf
   "de" 'org-docs-doc-recentf
   "dl" 'org-docs-find-last-doc-file
   "dd" 'org-docs-import-devdocs
   "db" 'org-docs-browse-source-url
   "du" 'org-docs-update-id-locations)
  :config
  (add-to-list 'recentf-exclude org-docs-dir)
  ;; `dr'/'dR'/'de'/'dl' read the doc-local recent files list, which only
  ;; fills up while `org-docs-recentf-mode' records visits (PC does the same).
  (org-docs-recentf-mode +1))

;; ====================
;; ANDROID EXTRAS (from ~/emacs-android/khalid-common.el)
;; ====================

;; tel: links open the Android dialer through Termux's `am'.
(org-link-set-parameters
 "tel"
 :follow (lambda (number)
           (start-process-shell-command
            "termux-dial"
            nil
            (concat "am start -a android.intent.action.DIAL -d tel:" number))))

(defun org-contacts--dial-number (number)
  "Dial NUMBER using Android's dialer via Termux.  Cleans for Tel URI."
  (let* ((cleaned (replace-regexp-in-string "[^+0-9*#]" "" number)))
    (start-process-shell-command
     "termux-dial" nil
     (concat "am start -a android.intent.action.DIAL -d tel:" cleaned))))

(defun org-contacts-dial-phone-at-point ()
  "Dial the number at point, preferring :TEL: then :item1.TEL:.
Uses Android's dialer via Termux."
  (interactive)
  (let* ((number (or (org-entry-get (point) "TEL")
                     (org-entry-get (point) "TEL;TYPE=\"voice,work\"")
                     (org-entry-get (point) "item1.TEL"))))
    (if number
        (org-contacts--dial-number number)
      (message "No usable phone number property found at point!"))))

(defun org-contacts-dial-any-phone-at-point ()
  "Interactively dial any TEL property on the entry at point.
Uses Termux's `am' command to open Android's dialer."
  (interactive)
  (let* ((all-props (org-entry-properties (point)))
         (tel-props
          (seq-filter
           (lambda (prop)
             (or (string-match-p "\\`TEL" (car prop))          ; TEL, TEL;TYPE=...
                 (string-match-p "\\`item[0-9]+\\.TEL\\'" (car prop)))) ; item1.TEL, etc.
           all-props))
         (choices
          (mapcar (lambda (prop)
                    (cons (format "%s: %s" (car prop) (cdr prop)) (cdr prop)))
                  tel-props)))
    (cond
     ((null choices)
      (message "No phone number found in properties at point!"))
     ((= 1 (length choices))
      (org-contacts--dial-number (cdar choices)))
     (t
      (let ((choice (completing-read "Choose number: " (mapcar #'car choices) nil t)))
        (org-contacts--dial-number (cdr (assoc choice choices))))))))

(provide 'khalid-org)
;;; khalid-org.el ends here
