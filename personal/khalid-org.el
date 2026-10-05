;;; khalid-org.el --- Org GTD core for Android  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-org.el: the GTD core (capture
;; templates, custom agenda commands, agenda file list, "o..." leader keys).
;; Dropped on purpose (heavy or PC-only): org-roam, org-pomodoro,
;; org-alert/habit-stats, activitywatch views ("oy"/"ov"), the "c" contacts
;; capture template (needs org-contacts), org-appear (kept off android on
;; the PC too).

;;; Code:

;; =================
;; GTD CORE CONFIGURATION
;; ====================

(defvar org-gtd-directory "~/org/gtd/")

(defun khalid/gtd-setup ()
  "Set up capture templates and agenda views (PC khalid-org.el, trimmed)."
  (let ((capture-file (concat org-gtd-directory "capture.org"))
        (gtd-file (concat org-gtd-directory "gtd.org"))
        (references-file (concat org-gtd-directory "references.org")))

    (setq org-capture-templates
          `(("i" "🎯 Capture" entry (file ,capture-file)
             "* TODO %?\nCAPTURED: %U\n" :empty-lines 1)
            ("t" "✅ Task" entry (file+headline ,gtd-file "✅ NEXT ACTIONS")
             "* TODO %? %^g\nCAPTURED: %U\n" :empty-lines 1)
            ("e" "📧 Email" entry (file+olp ,gtd-file "✅ NEXT ACTIONS" "💻 @computer")
             "* TODO %? :email:\nCAPTURED: %U\n" :empty-lines 1)
            ("p" "📁 Project" entry (file+headline ,gtd-file "📁 PROJECTS")
             "* %? %^g\nCAPTURED: %U" :empty-lines 1)
            ("w" "⏳ Waiting" entry (file+headline ,gtd-file "⏳ WAITING FOR")
             "* %? :waiting:\nCAPTURED: %U" :empty-lines 1)
            ("s" "💡 Someday" entry (file+headline ,gtd-file "💡 SOMEDAY/MAYBE")
             "* %? :someday:\nCAPTURED: %U" :empty-lines 1)
            ("n" "📝 Note" entry (file ,references-file)
             "* %? :note:\nCAPTURED: %U" :empty-lines 1)
            ;; Atomic Habits
            ("h" "🌱 Habit" entry (file+olp ,gtd-file "🌱 ATOMIC HABITS" "🔄 Daily Habits")
             "* TODO %?\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: TODO\n:END:\nCAPTURED: %U" :empty-lines 1)
            ("r" "🏆 Routine" entry (file+olp ,gtd-file "🌱 ATOMIC HABITS" "🔄 Daily Habits")
             "* %? :routine:\nCAPTURED: %U" :empty-lines 1)
            ("H" "🔄 Habit Check-in" entry (file+olp ,gtd-file "🌱 ATOMIC HABITS" "📈 Habit Tracking")
             "* Habit Check-in: %U\n- Energy: /10\n- Focus: /10\n- Completion: %\n- Notes: " :empty-lines 1)))

  ;; Custom Agenda Views - the GTD command center (ActivityWatch "A"/"e"
  ;; views omitted on the phone).
  (defun khalid/gtd-context-skip (context)
    "Skip entry unless it's a TODO under NEXT ACTIONS -> CONTEXT."
    (let ((path (org-get-outline-path t)))
      (unless (and
               (>= (length path) 2)
               (string-match-p "NEXT ACTIONS" (nth 0 path))
               (string-match-p context (nth 1 path)))
        (save-excursion (outline-next-heading) (point)))))

  (setq org-agenda-custom-commands
        `(("g" "🎯 GTD Contexts"
           ((tags-todo "+TODO=\"TODO\""
                       ((org-agenda-overriding-header "💻 Computer Tasks")
                        (org-agenda-files (list ,gtd-file))
                        (org-agenda-skip-function '(khalid/gtd-context-skip "@computer"))))
            (tags-todo "+TODO=\"TODO\""
                       ((org-agenda-overriding-header "📞 Phone Calls")
                        (org-agenda-files (list ,gtd-file))
                        (org-agenda-skip-function '(khalid/gtd-context-skip "@phone"))))
            (tags-todo "+TODO=\"TODO\""
                       ((org-agenda-overriding-header "🛒 Errands")
                        (org-agenda-files (list ,gtd-file))
                        (org-agenda-skip-function '(khalid/gtd-context-skip "@errands"))))
            (tags-todo "+TODO=\"TODO\""
                       ((org-agenda-overriding-header "🏠 Home Tasks")
                        (org-agenda-files (list ,gtd-file))
                        (org-agenda-skip-function '(khalid/gtd-context-skip "@home"))))
            (tags-todo "+TODO=\"TODO\""
                       ((org-agenda-overriding-header "👥 Agenda Items")
                        (org-agenda-files (list ,gtd-file))
                        (org-agenda-skip-function '(khalid/gtd-context-skip "@agenda"))))))
          ("i" "🎯 Capture Review" tags "capture"
           ((org-agenda-overriding-header "🎯 Capture Items to Process")))
          ("w" "Weekly Review"
           ((agenda ""
                    ((org-agenda-overriding-header "Completed Tasks")
                     (org-agenda-skip-function '(org-agenda-skip-entry-if 'nottodo 'done))
                     (org-agenda-span 'week)))
            (agenda ""
                    ((org-agenda-overriding-header "Unfinished Scheduled Tasks")
                     (org-agenda-skip-function '(org-agenda-skip-entry-if 'todo 'done))
                     (org-agenda-span 'week)))))
          ("d" "Today's Agenda" agenda ""
           ((org-agenda-buffer-name "*Today's Agenda*")
            (org-agenda-span 'day)
            (org-habit-show-habits-only-for-today t)
            (org-habit-preceding-days 7)
            (org-habit-following-days 1)
            (org-agenda-overriding-header "What to do today?")))
          ("h" "🌱 Habits Review" tags "habit|routine"
           ((org-agenda-overriding-header "🌱 Daily Habits Check-in")
            (org-agenda-sorting-strategy '(priority-down)))))))

  (mapc (lambda (f)
          (let ((filename (concat org-gtd-directory f)))
            (when (file-exists-p filename)
              (add-to-list 'org-agenda-files filename))))
        '("gtd.org" "capture.org" "calendar.org" "habits.org" "clocking.org"
          "accountability.org" "atomic-habits/workbook.org"))

  ;; Project TODOs.org files (subset of PC `khalid--projects-with-agenda').
  (mapc (lambda (f)
          (let ((filename (format "~/%s/TODOs.org" f)))
            (when (file-exists-p filename)
              (add-to-list 'org-agenda-files filename))))
        '("freshorama" "kshell" "khalids-shell" "org-docs"))

  (setq org-agenda-window-setup 'only-window))

;; ====================
;; KEYBINDINGS - Your GTD Shortcuts
;; ====================

(defun khalid/org-agenda-find-file ()
  "Find one of the `org-agenda-files'."
  (interactive)
  (find-file (completing-read "Find Org agenda file: " org-agenda-files nil t)))

(defun khalid/gtd-keybindings ()
  "Org leader keys (PC khalid-org.el; pomodoro/clock-cancel omitted)."
  (khalid/declare-prefix "o" "Org")
  (khalid/declare-prefix "oc" "clocks/contacts")

  (khalid/set-leader-keys
   "oF" (lambda () (interactive) (find-file (concat org-gtd-directory "capture.org")))
   "oG" (lambda () (interactive) (find-file (concat org-gtd-directory "gtd.org")))

   "oC" (lambda () (interactive) (org-capture nil "i"))
   "oT" 'org-capture
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

   "oa" (lambda () (interactive) (org-agenda nil "d"))
   "oA" (lambda () (interactive) (org-agenda nil "g"))
   "oh" 'consult-org-heading
   "ow" 'org-agenda-list
   "oW" (lambda () (interactive) (org-agenda nil "w"))
   "oz" 'org-agenda))

;; ====================
;; INITIALIZATION
;; ====================

(defun khalid/load-gtd ()
  (require 'org)
  (khalid/gtd-keybindings)
  (khalid/gtd-setup)
  (message "🎯 GTD system loaded successfully!"))

(use-package org
  :ensure nil
  :custom
  (org-directory "~/org")
  ;; Same choices as the PC (khalid-org.el / habits-setup):
  (org-agenda-start-on-weekday 6)          ;; week starts Friday
  (org-agenda-weekend-days '(5))
  (org-hide-emphasis-markers t)
  (org-use-property-inheritance '("effort" "category"))
  (org-log-into-drawer t)
  (org-habit-graph-column 60)
  (org-agenda-sorting-strategy
   '((agenda time-up urgency-down category-keep)
     (todo urgency-down category-keep) (tags urgency-down category-keep)
     (search category-keep)))
  :config
  (setopt org-refile-targets '((org-agenda-files :regexp . "*")))
  (setq org-archive-location (concat org-gtd-directory "archive.org::* From %s"))
  (keymap-set org-mode-map "C-<up>" 'org-shiftup)
  (keymap-set org-mode-map "C-<down>" 'org-shiftdown)
  (khalid/load-gtd))

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
