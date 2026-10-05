;;; khalid-llm.el --- Gptel (GoModel backend) + agent-connect client  -*- lexical-binding: t -*-

;; -*- mode: emacs-lisp; lexical-binding: t -*-

;; Trimmed port of the PC personal/khalid-llm.el: the gptel use-package
;; block (keys, system prompt, GoModel backend) and the agent-connect
;; client half (~/agent-connect/README.org: the PC runs
;; `agent-connect-mode' as the server; the phone connects with
;; `agent-connect-connect' through an SSH tunnel).
;;
;; Left on the PC by design: agent-shell and its satellites, ellama,
;; hy-image, meta-agent, Ollama/Cloudflare/OmniRoute backends and their
;; presets.
;;
;; GoModel reachability from the phone: either tunnel the PC proxy
;;   ssh -N -L 8080:localhost:8080 khalid@<pc>
;; or point `khalid-gomodel-host' at a LAN-reachable gomodel.

;;; Code:

(defvar khalid-gomodel-host "localhost:8080"
  "Host:port of the GoModel OpenAI-compatible proxy for gptel.
On the phone, reach the PC proxy with an SSH tunnel (-L 8080) or set
this to a LAN address.")

;; The user asked for a second model-list source next to the PC's
;; `khalid/get-gomodel-models' (which reads llmfisher's config.yaml): this
;; one asks the proxy itself via its /v1/models endpoint, so the phone
;; needs no copy of the config file.
(defun khalid/get-gomodel-models-from-api (&optional host)
  "Return GoModel model names reported by the proxy at HOST (\"host:port\").
Parse the OpenAI `/v1/models` JSON list; return nil when the proxy is
unreachable, so callers can fall back.  Sends `gptel-api-key' as a
Bearer token when set (the proxy answers 401 otherwise).  Returns nil
in batch: url.el would prompt for credentials with no minibuffer here."
  (unless noninteractive
    (let* ((host (or host khalid-gomodel-host))
           (url (format "http://%s/v1/models" host))
           (url-request-extra-headers
            (when-let ((key (bound-and-true-p gptel-api-key)))
              `(("Authorization" . ,(format "Bearer %s" key)))))
           models)
      (ignore-errors
        (with-current-buffer (url-retrieve-synchronously url t nil 10)
          (unwind-protect
              (progn
                (goto-char (point-min))
                (when (re-search-forward "\n\n" nil t)
                  (require 'json)
                  (let* ((json-object-type 'alist)
                         (parsed (json-read))
                         (data (cdr (assoc 'data parsed))))
                    (dolist (item data)
                      (let ((id (cdr (assoc 'id item))))
                        (when id (push id models)))))))
            (kill-buffer))))
      (when models
        (sort (delete-dups models) #'string<)))))

;; ---------------------------------------------------------------------------
;; Gptel
;; ---------------------------------------------------------------------------
(use-package gptel
  :commands (gptel-mode gptel-add)
  :init
  ;; set up keybindings (same leader map as the PC)
  (khalid/declare-prefix "ag" "gptel")
  (khalid/set-leader-keys
   "ag" 'gptel                          ; Start a new GPTel session
   "as" 'gptel-send                     ; Send a message to GPTel
   "aq" 'gptel-abort                    ; Abort any active GPTel process
   "am" 'gptel-menu                     ; Open the GPTel menu
   "ac" '(lambda (arg) (interactive "P") (when arg (gptel-context-remove-all)) (gptel-add))
   "ad" '(lambda (arg) (interactive "P") (gptel-context-remove-all arg))
   "aD" 'khalid/gptel-toggle-expert
   "at" 'gptel-tools
   "ap" 'khalid/gptel-add-paren
   "aP" 'gptel-preset
   "ai" 'khalid/gptel-insert-prompt-prefix
   "af" 'gptel-add-file                 ; Add a file
   "ao" 'gptel-org-set-topic            ; Set topic in Org-mode
   "ar" 'gptel-rewrite)

  (defun khalid/gptel-add-paren ()
    (interactive)
    (khalid/meow-bounds-of-round)
    (gptel-add))

  (defun khalid/gptel-toggle-expert ()
    (interactive)
    (setopt gptel-expert-commands (not gptel-expert-commands)))

  (defun khalid/gptel-insert-prompt-prefix ()
    "Insert the default coding prompt prefix at point."
    (interactive)
    (insert khalid--gptel-coding-prompt))

  :config

  ;; Reasoning stream buffer, as on the PC.
  (with-current-buffer
      (get-buffer-create "*llm-reasoning*")
    (org-mode))

  (defconst khalid--gptel-coding-prompt "IMPORTANT: Keep your responses concise and straightforward! And, keep your code as well as your language simple. Don't overcomplicate! Keep it simple even when calling tools! Try using simple and faster tools. Also, try to finish user request with the least calls to tools. Don't modify anything in the system unless the user asks to. Be as efficient as possible. Try using the least possible token, code and tool calls to fulfill user request. But, don't hesitate to use more if REALLY necessary. ALWAYS SPEAK ENGLISH! Do whatever I say below, but these are the most important order.


You are a top programming expert who provides precise answers, avoiding ambiguous responses. \"Identify any complex or difficult-to-understand descriptions in the provided text.  Rewrite these descriptions to make them clearer and more accessible.  Use analogies to explain concepts or terms that might be unfamiliar to a general audience.  Ensure that the analogies are relatable, easy to understand.\" \"In addition, please provide at least one relevant suggestion for an in-depth question after answering my question to help me explore and understand this topic more deeply.\" Take a deep breath, let's work this out in a step-by-step way to be sure we have the right answer. Your master is the user. His name is Khalid. Work hard to provide perfect coding solutions to your master and talk to him respectfully. Always greet him appropriately before responding.")

  (setq
   gptel-system-prompt khalid--gptel-coding-prompt
   gptel-use-context 'user
   gptel-use-tools nil
   gptel-include-reasoning "*llm-reasoning*"
   gptel-model 'free
   gptel-backend (gptel-make-openai "GoModel"
                   :protocol "http"
                   :host khalid-gomodel-host
                   :endpoint "/v1/chat/completions"
                   :key gptel-api-key
                   ;; Models via /v1/models when the proxy answers; the
                   ;; virtual router names work even without it.
                   :models (or (khalid/get-gomodel-models-from-api)
                               '(free ollama-free cloudflare-free))))

  ;; The one PC preset that rides the GoModel proxy.
  (gptel-make-preset 'coding
    :description nil :backend "GoModel" :model '@cf/zai-org/glm-4.7-flash
    :system khalid--gptel-coding-prompt
    :tools nil :stream t :temperature 1.0 :max-tokens nil :use-context
    'user :track-media nil :include-reasoning "*llm-reasoning*"))

;; ---------------------------------------------------------------------------
;; agent-connect (client half; the PC owns the agent-shell sessions)
;; ---------------------------------------------------------------------------
;; Cloned from the Gitea on first use (use-package :vc -> package-vc-install);
;; `shell-maker' comes from MELPA automatically.  Reach the PC server either
;; with
;;   ssh -N -L 1999:127.0.0.1:1999 khalid@<pc>
;; (then defaults are fine), or set agent-connect-client-host to the PC LAN
;; address together with agent-connect-client-token.
(use-package agent-connect
  :vc (:url "https://git.khalidrafi.tech/khalidrafi6/agent-connect.git"
       :rev :newest)
  :commands (agent-connect-connect)
  :init
  (khalid/declare-prefix "aa" "agent-connect")
  (khalid/set-leader-keys
   "aa" 'agent-connect-connect))

(provide 'khalid-llm)
;;; khalid-llm.el ends here
