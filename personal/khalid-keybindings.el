;;; khalid-keybindings.el --- leader machinery, meow, completion  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Ported from the PC config, kept deliberately small:
;;   modules/prelude-evil.el    -> khalid/string-spacer, khalid/set-leader-keys,
;;                                khalid/declare-prefix (verbatim logic; these
;;                                define the phone's muscle memory)
;;   modules/khalid-meow.el     -> meow with the PC's full key set (meow's
;;                                own defaults are nearly empty since the
;;                                1.5 keymap rework, so the PC defines every
;;                                key itself; we copy that)
;;   modules/prelude-vertico.el -> vertico + orderless + marginalia + consult
;;   personal/khalid-keybindings.el -> a few common leader keys
;;
;; Leader keys are plain global bindings: "C-c <k1> <k2>" per leader string
;; (meow-keypad-leader-dispatch is "C-c"), and a key starting with "x" uses
;; the C-x prefix -- so e.g. telega "xt" is C-x C-t, gptel "ag" is C-c a g,
;; exactly like the PC.

;;; Code:

;; which-key first: `khalid/declare-prefix' calls into it at load time.
;; Like the PC, the minor mode itself stays OFF (PC init.el runs
;; `which-key-mode 0'); the annotations are still registered.
(use-package which-key
  :demand t
  :config
  (which-key-setup-side-window-right)
  (which-key-mode 0))

(defun khalid/string-spacer (str &optional ctrl)
  "Split STR into \"k1 k2 ...\"; with CTRL make each char \"C-<char>\".
\"SPC\" and single characters are returned unchanged."
  (if (and (length> str 1) (not (equal str "SPC")))
      (string-join
       (if ctrl
           (mapcar (lambda (char) (format "C-%s" char))
                   (string-split str "" t))
         (string-split str "" t))
       " ")
    str))

;; The PC dispatches meow's keypad to C-c; set-leader-keys builds its key
;; sequences against this variable, so keep them identical.
(setq meow-keypad-leader-dispatch "C-c")

(defun khalid/set-leader-keys (key def &rest bindings)
  "Bind leader-style KEY strings to DEF, continuing with BINDINGS pairs.
\"ag\" means C-c a g; a KEY starting with \"x\" means the C-x prefix,
so \"xt\" becomes C-x C-t (exactly like the PC)."
  (while key
    (if (equal (substring key 0 1) "x")
        (keymap-set global-map (khalid/string-spacer key t) def)
      (keymap-set global-map (format "%s %s" meow-keypad-leader-dispatch (khalid/string-spacer key)) def))
    (setq key (pop bindings) def (pop bindings))))

(defun khalid/declare-prefix (prefix name &rest more)
  "Declare a prefix PREFIX.  PREFIX is a string describing a key
sequence.  NAME is a string used as the prefix command."
  (declare (indent defun))
  (dolist (state (list "<normal-state>" "<insert-state>" "<emacs-state>"))
    (apply #'which-key-add-keymap-based-replacements global-map
           (concat state "<leader>" prefix) name more)))

;; ---------------------------------------------------------------------------
;; Meow: modal editing, light port of modules/khalid-meow.el
;; ---------------------------------------------------------------------------
(use-package surround
  :defer nil
  :bind-keymap ("M-'" . surround-keymap))

(use-package meow
  :demand t
  :custom
  (meow-use-clipboard t)
  :config
  ;; Same keypad conventions as the PC.
  (setq meow-join-key "g")
  (setq meow-visit-key "M-/")
  (setq khalid--meow-mark-key "m")
  (setq khalid--meow-search-current-symbol-key "*")
  (setq khalid--meow-pop-to-mark-key "C-o")
  (setopt meow-keypad-ctrl-meta-prefix ?z)

  (defun khalid/meow-search-current-symbol ()
    (interactive)
    (meow-mark-symbol 0)
    (meow-search nil))

  (defun khalid/meow-bounds-of-round ()
    "Select the round (paren) body around point, for gptel context."
    (meow-bounds-of-thing 114))

  (defalias 'meow-save-whole-line (kmacro "v y"))

  ;; PC selection fallbacks (the subset that makes sense without beacon/etc).
  (setopt meow-selection-command-fallback
          '((meow-change . meow-change-char)
            (meow-kill . meow-kill-whole-line)
            (meow-save . meow-save-whole-line)
            (meow-cancel-selection . ignore)
            (meow-pop-selection . meow-pop-grab)
            (meow-expand . meow-digit-argument)))

  ;; Vim-like word motion for w/e (verbatim from khalid-meow.el): the PC's
  ;; word boundaries are not the Elisp defaults, so keep them identical.
  (defun forward-vimlike-word (&optional arg)
    "Alternate `forward-word'.  Essentially the same idea as Vim's 'e'."
    (interactive "^p")
    (setq arg (or arg 1))
    (cl-destructuring-bind (sign move-func char-func)
        (if (>= arg 0)
            '(1 skip-syntax-forward char-after)
          '(-1 skip-syntax-backward char-before))
      (with-syntax-table (standard-syntax-table)
        (let ((distance sign))
          (while (and distance (> (abs distance) 0) (> (* arg sign) 0))
            (setq distance
                  (when-let ((next-char (funcall char-func))
                             (next-syntax (char-syntax next-char)))
                    (cond ((eq next-syntax ?w)
                           (funcall move-func "w"))
                          ((eq next-syntax ?\ )
                           (prog1
                               (funcall move-func " ")
                             (forward-vimlike-word sign)))
                          (t
                           (funcall move-func "^w ")))))
            (setq arg (- arg sign)))
          (and distance (> (abs distance) 0))))))
  (put 'vimlike-word 'forward-op #'forward-vimlike-word)
  (setopt meow-word-thing 'vimlike-word)

  ;; Extra things: t=tag, o=org-element, [/]=first/last line (PC).
  (meow-thing-register 'tag '(regexp "<.+>" "</.+>") '(regexp "<.+>" "</.+>"))
  (defun meow-org-element-bounds ()
    (cons (org-element-property :begin (org-element-at-point))
          (org-element-property :end (org-element-at-point))))
  (meow-thing-register 'org-element 'meow-org-element-bounds 'meow-org-element-bounds)
  (defun meow-first-line-bounds ()
    (save-excursion (goto-char (point-min)) (cons (point) (line-end-position))))
  (defun meow-last-line-bounds ()
    (save-excursion (goto-char (point-max)) (cons (point) (line-end-position))))
  (meow-thing-register 'first-line 'meow-first-line-bounds 'meow-first-line-bounds)
  (meow-thing-register 'last-line 'meow-last-line-bounds 'meow-last-line-bounds)
  (setopt meow-char-thing-table
          (append meow-char-thing-table
                  '((?o . org-element)
                    (?\[ . first-line)
                    (?\] . last-line))))

  ;; Meow's built-in normal/motion keymaps are nearly empty (since the
  ;; 1.5-keymap rework, which the PC's meow has too): the PC defines its
  ;; whole key set itself in `meow-setup', so we port that verbatim to
  ;; keep the phone's muscle memory identical.
  (meow-leader-define-key
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument))

  (meow-motion-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("\\" . meow-inner-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   `(,meow-join-key . meow-join)
   '("n" . meow-search)
   '("%" . meow-block)
   '("I" . meow-to-block)
   '("q" . meow-quit)
   '("G" . meow-goto-line)
   '("t" . meow-till)
   `(,meow-visit-key . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("v" . meow-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("C-c <tab>" . meow-insert)
   '("/" . consult-line)
   `(,khalid--meow-pop-to-mark-key . meow-pop-to-mark)
   `(,khalid--meow-search-current-symbol-key . khalid/meow-search-current-symbol)
   `(,khalid--meow-mark-key . set-mark-command)
   '("<escape>" . meow-cancel-selection))

  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("\\" . meow-inner-of-thing)
   '("`" . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("x" . meow-delete)
   '("X" . meow-backward-delete)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("V" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("o" . meow-open-below)
   '("O" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   `(,meow-join-key . meow-join)
   '("n" . meow-search)
   '("%" . meow-block)
   '("I" . meow-to-block)
   '("q" . meow-quit)
   '("t" . meow-till)
   '("a" . meow-append)
   '("p" . meow-yank)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("d" . meow-kill)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   `(,meow-visit-key . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("v" . meow-line)
   '("G" . meow-goto-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("/" . consult-line)
   '("'" . meow-change-char)
   '("," . "C-,")
   `(,khalid--meow-pop-to-mark-key . meow-pop-to-mark)
   '("C-]" . meow-unpop-to-mark)
   '("C-r" . undo-redo)
   '("S" . surround-insert)
   (cons "s" surround-keymap)
   '("=" . meow-indent)
   `(,khalid--meow-search-current-symbol-key . khalid/meow-search-current-symbol)
   `(,khalid--meow-mark-key . set-mark-command)
   '("<escape>" . meow-cancel-selection))

  (meow-define-keys 'insert
    '("C-c <escape>" . meow-motion-mode)
    '("C-y" . yank)
    '("C-z" . meow-undo)
    '("C-r" . undo-redo))

  ;; Same escape hatches and help keys as the PC.
  (keymap-set global-map "C-<escape>" 'meow-motion-mode)
  (keymap-set global-map "C-h /" 'meow-keypad-describe-key)
  (keymap-set global-map "C-h C-t" 'meow-tutor)

  ;; Mode states, trimmed to what this config loads (telega browses in
  ;; motion state like on the PC).
  (setopt meow-mode-state-list '((fundamental-mode . normal)
                                 (help-mode . motion)
                                 (Info-mode . motion)
                                 (prog-mode . normal)
                                 (text-mode . normal)
                                 (telega-root-mode . motion)))

  (meow-global-mode 1))

;; ---------------------------------------------------------------------------
;; Completion: vertico + orderless + marginalia + consult
;; (Corfu is skipped: an on-screen keyboard fights popup completion)
;; ---------------------------------------------------------------------------
(use-package vertico
  :init (vertico-mode)
  :custom (vertico-cycle t))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :commands (consult-line consult-org-heading))

;; ---------------------------------------------------------------------------
;; Common leader keys, subset of personal/khalid-keybindings.el
;; ---------------------------------------------------------------------------
(khalid/declare-prefix "b" "buffers")
(khalid/declare-prefix "f" "files")
(khalid/declare-prefix "w" "windows")

(khalid/set-leader-keys
 "wo" 'delete-other-windows
 "wh" 'split-window-horizontally
 "wv" 'split-window-vertically
 "wd" 'delete-window
 "fs" 'save-buffer
 "ff" 'find-file
 "fp" 'find-file-at-point
 "bs" 'scratch-buffer
 "bd" 'kill-current-buffer
 "<left>" 'previous-buffer
 "<right>" 'next-buffer)

;; C-s saves, C-x C-s jumps to scratch (PC khalid-keybindings.el).
(keymap-unset global-map "C-s" t)
(keymap-unset global-map "C-x C-s" t)
(keymap-set global-map "C-s" 'save-buffer)
(keymap-set global-map "C-x C-s" 'scratch-buffer)

(provide 'khalid-keybindings)
;;; khalid-keybindings.el ends here
