;;; org-sc.el : Run SuperCollider in org-mode

(defun org-sc-eval (replace-p &optional enclosure)
  "Evaluate contents of org-mode element as SuperCollider code.
If inside a section, evaluate whole contents of section.
If inside a src block, evaluate contents of block.
If REPLACE-P is not nil, then remove all processes from the previous
evaluation of this section before evaluating the string.
If REPLACE-P is '(16) (C-u C-u), then just stop all processes of this section.

ENCLOSURE is a format string to inject the string into. It defaults to %s
org-sc-eval-as-routine uses enclosure to enclose the string link like this:
{ %s }.for;"
  (interactive "P")
  (let* ((element (org-element-at-point))
         (plist (cadr element))
         end
         (string
          (if (equal (car element) 'src-block)
              (plist-get (cadr element) :value)
            (org-get-section-contents))))
    (org-sc-eval-string-with-id string replace-p enclosure)))

(defun org-get-section-contents ()
  "Get the contents substring of an org-mode section, without the property drawer."
  (save-restriction
    (widen)
    (org-back-to-heading)
    (let* ((element (org-element-at-point))
           (plist (cadr element))
          (end (plist-get plist :end)))
     (goto-char (plist-get plist :contents-begin))
     ;; skip property drawer if it exists:
     (setq element (org-element-at-point))
     (if (equal 'property-drawer (car element))
         (goto-char (plist-get (cadr element) :end)))
     (buffer-substring-no-properties (point) end))))

(defun org-sc-eval-string-with-id (string &optional replace-p enclosure)
  "Eval string in SuperCollider, providing the id of the section
from which the string originates and the number of times that
this section has been evaluated as environment variables.
If REPLACE-P is not nil, then remove all processes from the previous
evaluation of this section before evaluating the string.
If REPLACE-P is '(16) (C-u C-u), then just stop all processes of this section.

ENCLOSURE is a format string to inject the string into. It defaults to %s
org-sc-eval-as-routine uses enclosure to enclose the string link like this:
{ %s }.for;
"
  (let ((eval-id (or (org-entry-get (point) "eval-id") "1"))
        (source-id (org-id-get-create)))
    (if replace-p
        (sclang-eval-string
         (concat
          "ProcessRegistry.removeProcessesForID('"
          source-id
          "', "
          eval-id
          ");"
          ))
      (setq eval-id (format "%d" (+ 1 (eval (read eval-id))))))
    (unless (equal replace-p '(16))
      (org-set-property "eval-id" eval-id)
      (sclang-eval-string
       (concat
        "(source_id: '"
        source-id
        "', eval_id: "
        eval-id
        ") use: {\n"
        (format (or enclosure "%s") string)
        "\n}")
       t))
    ))

(defun org-sc-eval-in-routine (replace-p)
  "Run org-sc-eval enclosing the string of the section to make it run
in a routine:
{ <code to be evaluated> }.for;"
  (interactive "P")
  (org-sc-eval replace-p "{ %s }.for;"))

(defun org-sc-eval-next (replace-p)
  "Go to next org-mode section and evaluate its contents as SuperCollider code."
  (interactive "P")
  (outline-next-heading)
  (org-sc-eval replace-p))

(defun org-sc-eval-previous (replace-p)
  "Go to previous org-mode section and evaluate its contents as SuperCollider code."
  (interactive "P")
  (outline-previous-heading)
  (org-sc-eval replace-p))

(defun org-sc-stop-section-processes ()
  "Stop the nodes, routines, patterns started from the current org-section."
  (interactive)
  (sclang-eval-string
   (concat
    "ProcessRegistry.removeProcessesForID('"
    (org-id-get-create)
    "')")))

(defun org-sc-toggle-mode ()
  "Toggle between org-mod an sc-mode for editing/running code."
  (interactive)
  (cond ((equal major-mode 'org-mode)
         (sclang-mode))
        (t
         (org-mode)
         (org-show-entry))))

(defun org-goto-contents-begin ()
  "Go to the first line of contents of a section, skipping the property drawer."
  (save-restriction
    (widen)
    (org-back-to-heading)
    (let* ((element (org-element-at-point))
           (plist (cadr element))
           (end (plist-get plist :end)))
      (goto-char (plist-get plist :contents-begin))
      ;; skip property drawer if it exists:
      (setq element (org-element-at-pSoint))
      (if (equal 'property-drawer (car element))
          (goto-char (plist-get (cadr element) :end))))))

(defun org-sc-next-section ()
  "Go to the next section, and jump to the beginning of the code,
skipping the property drawer. Show contents of section."
  (interactive)
  (outline-next-heading)
  (org-show-entry)
  (org-goto-contents-begin))

(defun org-sc-previous-section ()
  "Go to the previous section, and jump to the beginning of the code,
skipping the property drawer.  Show contents of section."
  (interactive)
  (org-back-to-heading)
  (outline-previous-heading)
  (org-show-entry)
  (org-goto-contents-begin))

(defvar org-track-autoload-property-with-tag t
  "If not nil, then also set the autoload tag with the property,
for improved visibility")

(defun org-sc-toggle-autoload ()
  "Toggle the AUTOLOAD property of the current entry.
For better visibility, you can track the value of this property with a tag.
See variable `org-track-autoload-property-with-tag'.
Adapted from org-toggle-ordered-property."
  (interactive)
  (let* ((t1 org-track-autoload-property-with-tag)
         (tag (and t1 (if (stringp t1) t1 "AUTOLOAD"))))
    (save-excursion
      (org-back-to-heading)
      (if (org-entry-get nil "AUTOLOAD")
          (progn
            (org-delete-property "AUTOLOAD" "PROPERTIES")
            (and tag (org-toggle-tag tag 'off))
            ;; (message "Subtasks can be completed in arbitrary order")
            )
        (org-entry-put nil "AUTOLOAD" "t")
        (and tag (org-toggle-tag tag 'on))
        ;; (message "Subtasks must be completed in sequence")
        ))))

(defun org-sc-load-marked ()
  "Load the code of all sections marked with property AUTOLOAD set to non-nil."
  (interactive)
  (save-excursion
   (save-restriction
     (widen)
     (run-hook-with-args 'org-pre-cycle-hook 'all)
     (show-all)
     (run-hook-with-args 'org-cycle-hook 'all)
     (org-map-entries
     (lambda ()
       (sclang-eval-string
        (org-get-section-contents)
        t))
     "AUTOLOAD" 'file))))



;; Select a SynthTree instance to chuck current expression into
;; Proof of principle.

(defvar org-sc-selected-synthtree "sound1"
"Store name of last synthtree selected, to act as default for
org-sc-chuck-selecting-into-synthtree.")

(defun org-sc-faders ()
  "Open global faders window in SuperCollider."
  (interactive)
  (sclang-eval-string "SynthTree.faders;"))

(defun org-sc-chuck-into-last-synthtree ()
  "Chuck current SC expression into latest selected SynthTree."
  (interactive)
  (sclang-eval-string
   (format
    "{ %s } => \\%s"
    (sclang-get-current-snippet) org-sc-selected-synthtree)))

(defun org-sc-chuck-selecting-into-synthtree (synthtree-list)
  "Select a synthtree returned from SC and chuck current SC expression
into it.  This function is called by SC in response to
org-sc-select-synthtree-then-chuck"
  (let (expression
        (synthtree
         (completing-read-ido "Select synthtree to chuck into: " synthtree-list
                               nil nil nil nil org-sc-selected-synthtree
                              )))
    (setq org-sc-selected-synthtree synthtree)
    (if (equal major-mode 'sclang-mode)
        (setq expression (sclang-get-current-snippet))
      (setq expression (org-get-section-contents)))
    (sclang-eval-string (format "{ %s } => \\%s" expression synthtree))))

(defun org-sc-select-synthtree-then-chuck ()
  "Select or enter a synthree, then chuck current snippet or org-mode section
into it.  This is the interactive function called by keyboard command."
  (interactive)
  (sclang-eval-string "SynthTree.chuckSelectingSynthTree;"))

(defun org-sc-select-synthtree-then-knobs (select-last)
  "Select or enter a synthree, then chuck current snippet or org-mode section
into it.  This is the interactive function called by keyboard command."
  (interactive "P")
  (if select-last
      (sclang-eval-string
       (format "'%s'.knobs" org-sc-selected-synthtree))
    (sclang-eval-string "SynthTree.knobsSelectingSynthTree;")))

(defun org-sc-select-eval-snippet
  (selection-list format-string &optional prompt require-match)
  "Perform the current snippet or org-mode section in sclang formatted
with format-string and with a string selected from selection-list,
sent by sclang."
  (setq prompt (or prompt "Select (default: %s): "))
  (setq prompt (format prompt org-sc-selected-synthtree))
  (let (expression
        (selection
         (ido-completing-read   ;; completing-read-ido
          prompt selection-list
          nil require-match nil nil org-sc-selected-synthtree)))
    (setq org-sc-selected-synthtree selection)
    (if (equal major-mode 'sclang-mode)
        (setq expression (sclang-get-current-snippet))
      (setq expression (org-get-section-contents)))
    (sclang-eval-string (format format-string expression selection))))

(defun org-sc-select-eval
  (selection-list format-string &optional prompt require-match)
  "Perform in sclang an expression created with
format-string and with a string selected from selection-list,
sent by sclang."
  (setq prompt (or prompt "Select (default: %s): "))
  (setq prompt (format prompt org-sc-selected-synthtree))
  (let ((selection
         (ido-completing-read   ;; completing-read-ido
          prompt selection-list
          nil require-match nil nil org-sc-selected-synthtree)))
    (setq org-sc-selected-synthtree selection)
    (sclang-eval-string (format format-string selection))))

(defun org-sc-toggle-synthtree (last-one)
  (interactive "P")
  (if last-one
      (sclang-eval-string (format "'%s'.toggle" org-sc-selected-synthtree))
      (sclang-eval-string "SynthTree.toggleSelectingSynthTree;")))

(defun org-sc-toggle-last-synthtree (fadeTime)
  (interactive "P")
  (sclang-eval-string
   (format "'%s'.toggle(%s)"
           org-sc-selected-synthtree
           (if fadeTime
               (if (numberp fadeTime) fadeTime (/ (car fadeTime) 4))
             ""))))

(defun org-sc-start-synthtree (last-one)
  (interactive "P")
  (if last-one
      (sclang-eval-string (format "'%s'.start" org-sc-selected-synthtree))
    (sclang-eval-string "SynthTree.startSelectingSynthTree;")))

(defun org-sc-stop-synthtree (fadeTime)
  (interactive "P")
  (if fadeTime
      (sclang-eval-string (format
                "SynthTree.fadeOutSelectingSynthTree(nil, %s);"
                (if (numberp fadeTime) fadeTime (/ (car fadeTime) 4))))
    (sclang-eval-string "SynthTree.fadeOutSelectingSynthTree;")))

(defun org-sc-stop-last-synthtree (fadeTime)
  (interactive "P")
  (sclang-eval-string
   (format "'%s'.fadeOut(%s)"
           org-sc-selected-synthtree
           (if fadeTime
            (if (numberp fadeTime) fadeTime (car fadeTime))
            ""))))

(defun org-sc-play-buffer ()
  "Interactively select in emacs a buffer from the list of loaded buffers,
and play it in a SynthTree with the same name."
  (interactive)
  (sclang-eval-string "BufferList.selectPlay;"))

(defun org-sc-free-buffer ()
  "Interactively select in emacs a buffer from the list of loaded buffers,
free the SynthTree with the same name, and free the buffer"
  (interactive)
  (sclang-eval-string "BufferList.selectFree;"))

(defun org-sc-load-buffer ()
  "Load a buffer from file."
  (interactive)
  (sclang-eval-string "BufferList().loadBufferDialog;"))

(defun org-sc-save-buffer-list ()
  "Save list of paths of currently loaded buffers onto disk."
  (interactive)
  (sclang-eval-string "BufferList().saveListDialog;"))

(defun org-sc-open-buffer-list ()
  "Load all buffers from list stored onto disk."
  (interactive)
  (sclang-eval-string "BufferList().openListDialog;"))

(defun org-sc-show-buffer-list ()
  (interactive)
  (sclang-eval-string "BufferList.showList;"))

(global-set-key (kbd "H-c c") 'org-sc-select-synthtree-then-chuck)
(global-set-key (kbd "H-c H-c") 'org-sc-chuck-into-last-synthtree)
(global-set-key (kbd "H-c k") 'org-sc-select-synthtree-then-knobs)
(global-set-key (kbd "H-c f") 'org-sc-faders)
;; (global-set-key (kbd "H-c H-f") 'org-sc-set-global-fade-time)
;; (global-set-key (kbd "H-c H-C-f") 'org-sc-set-fade-time)
(global-set-key (kbd "H-c SPC") 'org-sc-toggle-synthtree)
(global-set-key (kbd "H-c H-SPC") 'org-sc-toggle-last-synthtree)
(global-set-key (kbd "H-c g") 'org-sc-start-synthtree)
(global-set-key (kbd "H-c s") 'org-sc-stop-synthtree)
(global-set-key (kbd "H-c H-s") 'org-sc-stop-last-synthtree)
(global-set-key (kbd "H-b g") 'org-sc-play-buffer)
(global-set-key (kbd "H-b l") 'org-sc-load-buffer)
(global-set-key (kbd "H-b L") 'org-sc-show-buffer-list)
(global-set-key (kbd "H-b o") 'org-sc-open-buffer-list)
(global-set-key (kbd "H-b s") 'org-sc-save-buffer-list)
(global-set-key (kbd "H-b f") 'org-sc-free-buffer)

(eval-after-load "org"
'(progn
   (define-key org-mode-map (kbd "H-C-o") 'org-sc-toggle-mode)
   (define-key org-mode-map (kbd "C-M-x") 'org-sc-eval)
   (define-key org-mode-map (kbd "C-c C-,") 'sclang-eval-line)
   ;; 9 because in the us keyboard it is below open paren:
   (define-key org-mode-map (kbd "C-c C-9") 'sclang-eval-dwim)
   (define-key org-mode-map (kbd "C-M-z") 'org-sc-stop-section-processes)
   (define-key org-mode-map (kbd "H-C-x") 'org-sc-eval-in-routine)
   ;; convenient parallel to H-C-x:
   (define-key org-mode-map (kbd "H-C-z") 'org-sc-stop-section-processes)
   (define-key org-mode-map (kbd "C-M-n") 'org-sc-eval-next)
   (define-key org-mode-map (kbd "C-M-p") 'org-sc-eval-previous)
   ;; this overrides the default binding org-schedule, which I do not use often:
   (define-key org-mode-map (kbd "C-c C-s") 'sclang-main-stop)
   (define-key org-mode-map (kbd "H-C-r") 'sclang-process-registry-gui)
   (define-key org-mode-map (kbd "C-c C-M-.") 'org-sc-stop-section-processes)
   (define-key org-mode-map (kbd "H-C-n  )") 'org-sc-next-section)
   (define-key org-mode-map (kbd "H-C-p") 'org-sc-previous-section)
   (define-key org-mode-map (kbd "C-c C-x l") 'org-sc-toggle-autoload)
   (define-key org-mode-map (kbd "C-c C-x C-l") 'org-sc-load-marked)))

(eval-after-load "sclang"
  '(progn
     (define-key sclang-mode-map (kbd "H-C-o") 'org-sc-toggle-mode)
     (define-key sclang-mode-map (kbd "C-c C-9") 'sclang-eval-dwim)))


(provide 'org-sc)

;;; end of org-sc.el
