;; Possibly relevant configuration for org-thesis

;;;;;;;;;;;;;;
;; Straight ;;
;;;;;;;;;;;;;;
;; Straight.el is a functional package manager for Emacs. It server as
;; a replacement for the native package.el

(setq-default straight-repository-branch "develop")

;; Bootstrap the package manager, straight.el.
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(defun straight-reload-init ()
  "Reload init.el."
  (interactive)
  (straight-transaction
   (straight-mark-transaction-as-init)
   (message "Reloading init.el...")
   (load user-init-file nil 'nomessage)
   (message "Reloading init.el... done.")))

;;;;;;;;;;;;;;;;;
;; use-package ;;
;;;;;;;;;;;;;;;;;

;; Use-package is a declarative package configurator.
;; We need to set some configurations before "requiring" use-package, so that it
;; integrates better with imenu and this init file.
(setq-default use-package-enable-imenu-support t
              use-package-form-regexp-eval
              `(concat ,(eval-when-compile
                          (concat "^\\s-*("
                                  (regexp-opt '("use-package" "use-feature" "require") t)
                                  "\\s-+\\("))
                       (or (bound-and-true-p lisp-mode-symbol-regexp)
                           "\\(?:\\sw\\|\\s_\\|\\\\.\\)+") "\\)"))

;; Call straight-use-package to bootstrap use-package so we can use it.
(straight-use-package 'use-package)

(defmacro use-feature (name &rest args)
  "Like `use-package', but with `straight-use-package-by-default' disabled."
  (declare (indent defun))
  `(use-package ,name
     :straight nil
     ,@args))

;; When configuring a feature with `use-package', also tell
;; straight.el to install a package of the same name, unless otherwise
;; specified using the `:straight' keyword.
(setq-default straight-use-package-by-default t)

;; Tell `use-package' to always load features lazily unless told
;; otherwise. It's nicer to have this kind of thing be deterministic:
;; if `:demand' is present, the loading is eager; otherwise, the
;; loading is lazy. See
;; https://github.com/jwiegley/use-package#notes-about-lazy-loading.
(setq-default use-package-always-defer t)

;;;;;;;;;;;;;;
;; Org Mode ;;
;;;;;;;;;;;;;;

;; Our real configuration for Org comes much later. Doing this now
;; means that if any packages that are installed in the meantime
;; depend on Org, they will not accidentally cause the Emacs-provided
;; (outdated and duplicated) version of Org to be loaded before the
;; real one is registered.
(use-package org
  :ensure org-contrib)
;; Here we guarantee that org mode gets loaded properly.
(use-package org-contrib)
;; Here we guarantee that org mode gets loaded properly.

(use-feature org
  ;; See an inspirational Org config here: https://github.com/novoid/dot-emacs/blob/master/config.org
  :config
  (setq-default org-catch-invisible-edits 'smart
                org-special-ctrl-a/e t
                org-image-actual-width '(400)
                org-return-follows-link t
                org-list-allow-alphabetical t
                ;; Aesthetics
                org-blank-before-new-entry '((heading . t) (plain-list-item . nil))
                org-fontify-quote-and-verse-blocks t
                org-hide-macro-markers nil
                org-fontify-whole-heading-line t
                org-fontify-done-headline t
                org-hide-emphasis-markers nil
                org-highlight-latex-and-related '(latex)
                ;; Image display
                org-image-actual-width '(400)
                ;; Agenda
                org-deadline-warning-days 40
                org-deadline-past-days 21)

  (add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))
  (add-to-list 'org-structure-template-alist '("sh" . "src sh"))
  (add-to-list 'org-structure-template-alist '("py" . "src python"))
  (add-to-list 'org-structure-template-alist '("j" . "src jupyter-python"))

  ;; After inserting an org template, also open a line.
  (defun org-structure-template-and-open-line (orig-func &rest args)
    (apply orig-func args)
    (unless mark-active
      (open-line 1)))

  (advice-add 'org-insert-structure-template
              :around #'org-structure-template-and-open-line)

  (defun scimax/org-return (&optional ignore)
    "Add new list item, heading or table row with RET.
A double return on an empty element deletes it.
Use a prefix arg to get regular RET. "
    (interactive "P")
    (if ignore
        (org-return)
      (cond
       ((eq 'line-break (car (org-element-context)))
        (org-return-indent))
       ;; Open links like usual, unless point is at the end of a line.
       ;; and if at beginning of line, just press enter.
       ((or (and (eq 'link (car (org-element-context))) (not (eolp)))
            (bolp))
        (org-return))
       ;; checkboxes too
       ((org-at-item-checkbox-p)
        (if (org-element-property :contents-begin
                                  (org-element-context))
            ;; we have content so add a new checkbox
            (org-insert-todo-heading nil)
          ;; no content so delete it
          (setf (buffer-substring (line-beginning-position) (point)) "")
          (org-return)))
       ;; lists end with two blank lines, so we need to make sure we are also not
       ;; at the beginning of a line to avoid a loop where a new entry gets
       ;; created with only one blank line.
       ((org-in-item-p)
        (if (save-excursion
              (beginning-of-line) (org-element-property :contents-begin (org-element-context)))
            (org-insert-item)
          (beginning-of-line)
          (delete-region (line-beginning-position) (line-end-position))
          (org-return)))
       ;; org-heading
       ((org-at-heading-p)
        (if (not (string= "" (org-element-property :title (org-element-context))))
            (progn
              ;; Go to end of subtree suggested by Pablo GG on Disqus post.
              (org-end-of-subtree)
              (org-insert-heading-respect-content)
              (outline-show-entry))
          ;; The heading was empty, so we delete it
          (beginning-of-line)
          (setf (buffer-substring
                 (line-beginning-position) (line-end-position)) "")))
       ;; tables
       ((org-at-table-p)
        (if (-any?
             (lambda (x) (not (string= "" x)))
             (nth
              (- (org-table-current-dline) 1)
              (remove 'hline (org-table-to-lisp))))
            (org-return)
          ;; empty row
          (beginning-of-line)
          (setf (buffer-substring
                 (line-beginning-position) (line-end-position)) "")
          (org-return)))
       ;; fall-through case
       (t
        (org-return)))))

  (defmacro unpackaged/def-org-maybe-surround (&rest keys)
    "Define and bind interactive commands for each of KEYS that surround the region or insert text.
  Commands are bound in `org-mode-map' to each of KEYS.  If the
  region is active, commands surround it with the key character,
  otherwise call `org-self-insert-command'."
    `(progn
       ,@(cl-loop for key in keys
                  for name = (intern (concat "unpackaged/org-maybe-surround-" key))
                  for docstring = (format "If region is active, surround it with \"%s\", otherwise call `org-self-insert-command'." key)
                  collect `(defun ,name ()
                             ,docstring
                             (interactive)
                             (if (region-active-p)
                                 (let ((beg (region-beginning))
                                       (end (region-end)))
                                   (save-excursion
                                     (goto-char end)
                                     (insert ,key)
                                     (goto-char beg)
                                     (insert ,key)))
                               (call-interactively #'org-self-insert-command)))
                  collect `(define-key org-mode-map (kbd ,key) #',name))))

  (unpackaged/def-org-maybe-surround "~" "=" "*" "/" "+" "$")

  (defun org-summary-todo (n-done n-not-done)
    "Switch entry to DONE when all subentries are done, to TODO otherwise."
    (let (org-log-done org-log-states)   ; turn off logging
      (org-todo (if (= n-not-done 0) "DONE" "TODO"))))

  :hook ((org-after-todo-statistics . org-summary-todo)
         (org-mode . visual-line-mode)
         (org-mode . visual-fill-column-mode)
         (org-mode . flycheck-mode)
         ;; (org-mode . flyspell-mode) ; Flyspell-mode bug when used with company. Activate only when necessary.
         (org-mode . (lambda ()
                       (push '("#+begin_src" . "λ") prettify-symbols-alist)
                       (push '("#+end_src" . "λ") prettify-symbols-alist)
                       (push '("#+begin_example" . "⁈") prettify-symbols-alist)
                       (push '("#+end_example" . "⁈") prettify-symbols-alist)
                       (push '("#+begin_quote" . "“") prettify-symbols-alist)
                       (push '("#+end_quote" . "”") prettify-symbols-alist)
                       (push '("#+begin_export" . "->") prettify-symbols-alist)
                       (push '("#+end_export" . "<-") prettify-symbols-alist)
                       (push '("jupyter-python" . "") prettify-symbols-alist)
                       (push '("#+RESULTS:" . "=") prettify-symbols-alist)
                       (push '(":results" . "=") prettify-symbols-alist)
                       (push '(":dir" . "") prettify-symbols-alist)
                       (push '(":session" . "@") prettify-symbols-alist)
                       (setq line-spacing 4)
                       (prettify-symbols-mode))))

  :bind (:map org-mode-map
              ("RET" . scimax/org-return)))

(use-feature org-src
  :after org
  :demand t
  :config
  (setq-default org-edit-src-content-indentation 0
                org-src-preserve-indentation t
                org-src-fontify-natively t))

(use-feature ob
  :after org
  :demand t
  :config
  (setq-default org-confirm-babel-evaluate nil
                org-confirm-elisp-link-function nil
                org-confirm-shell-link-function nil)

  (dolist (language '((org . t)
                      (python . t)
                      (matlab . t)
                      (shell . t)
                      (latex . t)))
    (add-to-list 'org-babel-load-languages language))
  (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages)

  :hook (org-babel-after-execute . org-display-inline-images))

(use-feature ox
  :after org
  :demand t
  :config
  ;; This is so that we are not queried if bind-keywords are safe when we set
  ;; org-export-allow-bind to t.
  (put 'org-export-allow-bind-keywords 'safe-local-variable #'booleanp)
  (setq org-export-with-sub-superscripts '{}
        org-export-coding-system 'utf-8
        org-html-checkbox-type 'html))

;; Once I reach feature parity with my old Spacemacs setup I should
;; make these configurations into a dedicated module.
(use-feature ox-latex
  :after ox
  :demand t
  :init (setq org-latex-pdf-process
              '("latexmk -pdflatex='pdflatex -shell-escape -interaction nonstopmode' -pdf -bibtex -f %f"))
  :config

  ;; Sometimes it's good to locally override these two.
  (put 'org-latex-title-command 'safe-local-variable #'stringp)
  (put 'org-latex-toc-command 'safe-local-variable #'stringp)

  ;; Need to let ox know about ipython and jupyter
  (add-to-list 'org-latex-minted-langs '(ipython "python"))
  (add-to-list 'org-babel-tangle-lang-exts '("ipython" . "py"))
  (add-to-list 'org-latex-minted-langs '(jupyter-python "python"))
  (add-to-list 'org-babel-tangle-lang-exts '("jupyter-python" . "py"))

  ;; Mimore class is a latex class for writing articles.
  (add-to-list 'org-latex-classes
               '("mimore"
                 "\\documentclass{mimore}
 [NO-DEFAULT-PACKAGES]
 [PACKAGES]
 [EXTRA]"
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}")
                 ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

  ;; Mimosis is a class I used to write my Ph.D. thesis.
  (add-to-list 'org-latex-classes
               '("mimosis"
                 "\\documentclass{mimosis}
 [NO-DEFAULT-PACKAGES]
 [PACKAGES]
 [EXTRA]
\\newcommand{\\mboxparagraph}[1]{\\paragraph{#1}\\mbox{}\\\\}
\\newcommand{\\mboxsubparagraph}[1]{\\subparagraph{#1}\\mbox{}\\\\}"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\mboxparagraph{%s}" . "\\mboxparagraph*{%s}")
                 ("\\mboxsubparagraph{%s}" . "\\mboxsubparagraph*{%s}")))

  ;; Elsarticle is Elsevier class for publications.
  (add-to-list 'org-latex-classes
               '("elsarticle"
                 "\\documentclass{elsarticle}
 [NO-DEFAULT-PACKAGES]
 [PACKAGES]
 [EXTRA]"
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}")
                 ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

  (setq org-latex-prefer-user-labels t))

;; Feature `ox-extra' is a library from the org-plus-contrib package.
;; It adds extra keywords and tagging functionality for org export.
(use-feature ox-extra
  ;; Demand so that ignore headlines is always active.
  :demand t
  :after ox
  ;; The ignore-headlines allows Org to understand the tag :ignore: and simply
  ;; remove tagged headings on export, but leave their content in.
  ;; See my blog post about writing thesis with org mode here:
  ;; https://write.as/dani/writing-a-phd-thesis-with-org-mode
  :config (ox-extras-activate '(ignore-headlines)))

;; Feature `org-compat' is a adapter layer so that org can communicate with other Emacs
;; built-in packages.
(use-feature org-compat
  :demand t
  :after org
  :config (setq org-imenu-depth 3))

;; Org-keys adds speed keys when cursor is at the beginning of a heading
(use-feature org-keys
  :demand t
  :after org
  :config (setq org-use-speed-commands t
                org-speed-commands-user '(("S" . org-store-link))))

;; Package `ob-async' allows executing ob commands asynchronously.
(use-package ob-async
  :disabled t
  :after ob
  :config
  ;; Jupyter defines its own async that conflicts with ob-async.
  (setq ob-async-no-async-languages-alist '("jupyter-python" "jupyter-julia")))

;; The `ox-word' library uses pandoc to export Org files to Microsoft Word via
;; LaTeX. It is currently a part of Kitchin's awesome Scimax project.
(use-package ox-word
  :after (:all org-ref ox)
  :demand t
  :straight (ox-word :type git
                     :host github
                     :repo "jkitchin/scimax"
                     :files ("ox-word.el")))

;; The `org-ref' package adds functionality to manage, insert and navigate
;; citations (and other references as well, such as equations) within Org mode.
(use-package org-ref
  :straight (org-ref :type git :host github :repo "jkitchin/org-ref" :branch "org-ref-2")
  :after org
  :demand t ;; Ensure that it loads so that links work immediately.
  :config
  (setq org-ref-default-bibliography '("~/project/org-thesis/thesis/thesis.bib")
        org-ref-get-pdf-filename-function 'org-ref-get-pdf-filename-helm-bibtex
        bibtex-completion-pdf-field "file"
        org-ref-default-citation-link "parencite")

  (defun org-ref-grep-pdf (&optional _candidate)
    "Search pdf files of marked CANDIDATEs."
    (interactive)
    (let ((keys (helm-marked-candidates))
          (get-pdf-function org-ref-get-pdf-filename-function))
      (helm-do-pdfgrep-1
       (-remove (lambda (pdf)
                  (string= pdf ""))
                (mapcar (lambda (key)
                          (funcall get-pdf-function key))
                        keys)))))

  (defun org-ref-open-pdf-at-point-in-emacs ()
    "Open the pdf for bibtex key under point if it exists."
    (interactive)
    (let* ((results (org-ref-get-bibtex-key-and-file))
           (key (car results))
           (pdf-file (funcall org-ref-get-pdf-filename-function key)))
      (if (file-exists-p pdf-file)
          (find-file-other-window pdf-file)
        (message "no pdf found for %s" key))))

  (defun org-ref-open-in-scihub ()
    "Open the bibtex entry at point in a browser using the url field or doi field.
Not for real use, just here for demonstration purposes."
    (interactive)
    (let ((doi (org-ref-get-doi-at-point)))
      (when doi
        (if (string-match "^http" doi)
            (browse-url doi)
          (browse-url (format "http://sci-hub.se/%s" doi)))
        (message "No url or doi found"))))

  (helm-add-action-to-source "Grep PDF" 'org-ref-grep-pdf helm-source-bibtex 1)

  ;; The following makes it possible to grep pdfs from the org-ref Helm
  ;; selection interface with C-s.
  (setq helm-bibtex-map
        (let ((map (make-sparse-keymap)))
          (set-keymap-parent map helm-map)
          (define-key map (kbd "C-s") (lambda () (interactive)
                                        (helm-run-after-exit 'org-ref-grep-pdf)))
          map))
  (push `(keymap . ,helm-bibtex-map) helm-source-bibtex)

  (setq org-ref-helm-user-candidates
        '(("Open in Sci-hub"  . org-ref-open-in-scihub)
          ("Open in Emacs" . org-ref-open-pdf-at-point-in-emacs))))

(use-package org-brain
  :init
  (setq org-brain-path "~/org/knowledge")
  (defun org-brain-insert-resource-icon (link)
    "Insert an icon, based on content of org-mode LINK."
    (insert (format "%s "
                    (cond ((string-prefix-p "http" link)
                           (cond ((string-match "wikipedia\\.org" link)
                                  (all-the-icons-faicon "wikipedia-w"))
                                 ((string-match "github\\.com" link)
                                  (all-the-icons-octicon "mark-github"))
                                 ((string-match "vimeo\\.com" link)
                                  (all-the-icons-faicon "vimeo"))
                                 ((string-match "youtube\\.com" link)
                                  (all-the-icons-faicon "youtube"))
                                 ((string-match "imdb\\.com" link)
                                  (all-the-icons-material "movie"))
                                 (t
                                  (all-the-icons-faicon "globe"))))
                          ((string-prefix-p "brain:" link)
                           (all-the-icons-fileicon "brain"))
                          ((string-prefix-p "cite:" link)
                           (all-the-icons-material "book"))
                          ((string-prefix-p "parencite:" link)
                           (all-the-icons-material "book"))
                          (t
                           (all-the-icons-icon-for-file link))))))

  :config
  (setq org-id-track-globally t)
  (setq org-id-locations-file "~/.emacs.d/.org-id-locations")
  (setq org-brain-visualize-default-choices 'all)
  (setq org-brain-title-max-length 100)

  (defun org-brain-open-org-noter (entry)
    "Open `org-noter' on the ENTRY.
If run interactively, get ENTRY from context."
    (interactive (list (org-brain-entry-at-pt)))
    (org-with-point-at (org-brain-entry-marker entry)
      (org-noter)))

  :commands org-brain-visualize

  :bind (:map org-brain-visualize-mode-map
              ("C-c n" . org-brain-open-org-noter))

  :hook
  (org-brain-visualize-mode . visual-line-mode)
  (org-brain-after-resource-button-functions . org-brain-insert-resource-icon))

(use-package org-cliplink
  :defer 5
  :after org)

(use-package org-noter
  :after org
  :commands org-noter
  :config (setq org-noter-default-notes-file-names nil
                ;; org-noter-always-create-frame nil
                org-noter-notes-search-path '("~/org/Research-Notes")
                org-noter-separate-notes-from-heading t))

;; Feature org-protocol is a part of org-plus-contrib.
(use-feature org-protocol
  :demand 5
  :after org
  :init
  (defun transform-square-brackets-to-round-ones(string-to-transform)
    "Transforms [ into ( and ] into ), other chars left unchanged."
    (concat
     (mapcar #'(lambda (c) (if (equal c ?\[) ?\( (if (equal c ?\]) ?\) c))) string-to-transform)))
  :config
  (setq org-capture-templates '(("t" "Todo [inbox]" entry
                                 (file+headline "~/gtd/inbox.org" "Tasks")
                                 "* TODO %i%?")
                                ("T" "Tickler" entry
                                 (file+headline "~/gtd/tickler.org" "Tickler")
                                 "* %i%? \n %U")
                                ("p" "Protocol" entry
                                 (file+headline "~/gtd/inbox.org" "Inbox")
                                 "* %^{Title}\nSource: [[%:link]] %u, %c\n #+BEGIN_QUOTE\n%i\n#+END_QUOTE\n\n\n %?")
                                ("L" "Protocol Link" entry
                                 (file+headline "~/gtd/inbox.org" "Inbox")
                                 "* %? [[%:link][%(transform-square-brackets-to-round-ones \"%:description\")]] %U\n")))

  (setq org-refile-targets '(("~/gtd/gtd.org" :maxlevel . 3)
                             ("~/gtd/someday.org" :level . 1)
                             ("~/gtd/readings.org" :maxlevel . 1)
                             ("~/gtd/random.org" :maxlevel . 1)
                             ("~/gtd/learning.org" :level . 1)
                             ("~/gtd/tickler.org" :maxlevel . 2)))

  (setq org-agenda-files '("~/gtd/inbox.org"
                           "~/gtd/gtd.org"
                           "~/gtd/tickler.org")))

;; Package org-download allows drag and drop of images directly into Emacs org-mode.
(use-package org-download
  :after org
  :demand t

  :commands (org-download-enable
             org-download-yank
             org-download-screenshot)

  :config
  (setq-default org-download-image-dir "./img")
  (setq org-download-screenshot-method "screencapture -i %s")

  :hook ((org-mode dired-mode) . org-download-enable))

;;;;;;;;;;;
;; Latex ;;
;;;;;;;;;;;

(use-package auctex)
(use-feature tex
  :config
  (setq-default TeX-auto-save t
                TeX-PDF-mode t
                Tex-show-compilation nil
                TeX-parse-self t)
  :hook ((LaTeX-mode . visual-line-mode)
         (LaTeX-mode . (lambda ()
                         (add-to-list
                          'TeX-command-list
                          '("XeLaTeX" "%`xelatex%(mode)%' %t" TeX-run-TeX nil t))))))

(use-feature tex-buf
  :config
  (setq TeX-save-query nil))

(use-package company-auctex
  :demand t
  :after (:all company tex)
  :config
  (company-auctex-init))

(use-package scimax-latex
  :straight (scimax-latex :type git
                          :host github
                          :repo "jkitchin/scimax"
                          :files ("scimax-latex.el"))
  :commands (scimax-latex-setup
             kpsewhich
             texdoc))
