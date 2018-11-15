;;; dune.el --- Integration with the dune build system

;; Copyright 2018 Jane Street Group, LLC <opensource@janestreet.com>
;;           2017- Christophe Troestler
;; URL: https://github.com/ocaml/dune
;; Version: 1.0

;;; Commentary:

;; This package provides helper functions for interacting with the
;; dune build system from Emacs.  It also prevides a mode to edit dune
;; files.

;; Installation:
;; You need to install the OCaml program ``dune''.  The
;; easiest way to do so is to install the opam package manager:
;;
;;   https://opam.ocaml.org/doc/Install.html
;;
;; and then run "opam install dune".

;; This file is not part of GNU Emacs.

;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
;; WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
;; AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
;; CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
;; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
;; NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
;; CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

;;; Code:

(defgroup dune nil
  "Integration with the dune build system."
  :tag "Dune build system."
  :version "1.0")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;               Syntax highlighting of dune files

(defface dune-error-face
  '((t (:inherit error)))
  "Face for errors (e.g. obsolete constructs)."
  :group 'dune)

(defvar dune-error-face 'dune-error-face
  "Face for errors (e.g. obsolete constructs).")

(defface dune-separator-face
  '((t (:inherit default)))
  "Face for various kind of separators such as ':'."
  :group 'dune)
(defvar dune-separator-face 'dune-separator-face
  "Face for various kind of separators such as ':'.")

(defconst dune-stanzas-regex
  (eval-when-compile
    (concat (regexp-opt
             '("library" "executable" "executables" "rule"
               "ocamllex" "ocamlyacc" "menhir" "alias" "install"
               "copy_files" "copy_files#" "include" "tests" "test"
               "env" "ignored_subdirs" "include_subdirs")
             ) "\\(?:\\_>\\|[[:space:]]\\)"))
  "Stanzas in dune files.")

(defconst dune-fields-regex
  (eval-when-compile
    (regexp-opt
     '("name" "public_name" "synopsis" "modules" "libraries" "wrapped"
       "preprocess" "preprocessor_deps" "optional" "c_names" "cxx_names"
       "install_c_headers" "modes" "no_dynlink" "kind"
       "ppx_runtime_libraries" "virtual_deps" "js_of_ocaml" "flags"
       "ocamlc_flags" "ocamlopt_flags" "library_flags" "c_flags"
       "cxx_flags" "c_library_flags" "self_build_stubs_archive"
       "modules_without_implementation" "private_modules"
       "allow_overlapping_dependencies"
       ;; + for "executable" and "executables":
       "package" "link_flags" "link_deps" "names" "public_names"
       ;; + for "rule":
       "targets" "action" "deps" "mode" "fallback" "locks"
       ;; + for "menhir":
       "merge_into"
       ;; + for "alias"
       "enabled_if"
       ;; + for "install"
       "section" "files")
     'symbols))
  "Field names allowed in dune files.")

(defconst dune-builtin-regex
  (eval-when-compile
    (concat (regexp-opt
             '(;; Linking modes
               "byte" "native" "best"
               ;; modes
               "standard" "fallback" "promote" "promote-until-clean"
               ;; Actions
               "run" "chdir" "setenv"
               "with-stdout-to" "with-stderr-to" "with-outputs-to"
               "ignore-stdout" "ignore-stderr" "ignore-outputs"
               "progn" "echo" "write-file" "cat" "copy" "copy#" "system"
               "bash" "diff" "diff?" "cmp"
               ;; FIXME: "flags" is already a field and we do not have enough
               ;; context to distinguishing both.
               "backend" "generate_runner" "runner_libraries" "flags"
               "extends"
               ;; Dependency specification
               "file" "alias" "alias_rec" "glob_files" "files_recursively_in"
               "universe" "package")
             t)
            "\\(?:\\_>\\|[[:space:]]\\)"))
  "Builtin sub-fields in dune")

(defconst dune-builtin-labels-regex
  (regexp-opt '("standard" "include") 'words)
  "Builtin :labels in dune")

(defvar dune-var-kind-regex
  (eval-when-compile
    (regexp-opt
     '("ocaml-config"
       "dep" "exe" "bin" "lib" "libexec" "lib-available"
       "version" "read" "read-lines" "read-strings")
     'words))
  "Optional prefix to variable names.")

(defmacro dune--field-vals (field &rest vals)
  `(list (concat "(" ,field "[[:space:]]+" ,(regexp-opt vals t))
         1 font-lock-constant-face))

(defvar dune-font-lock-keywords
  `((,(concat "(\\(" dune-stanzas-regex "\\)") 1 font-lock-keyword-face)
    ("([^ ]+ +\\(as\\) +[^ ]+)" 1 font-lock-keyword-face)
    (,(concat "(" dune-fields-regex) 1 font-lock-function-name-face)
    (,(concat "%{" dune-var-kind-regex " *\\(\\:\\)[^{}:]*\\(\\(?::\\)?\\)")
     (1 font-lock-builtin-face)
     (2 dune-separator-face)
     (3 dune-separator-face))
    ("%{\\([^{}]*\\)}" 1 font-lock-variable-name-face keep)
    (,(concat "\\(:" dune-builtin-labels-regex "\\)[[:space:]()\n]")
     1 font-lock-builtin-face)
    ;; Named dependencies:
    ("(\\(:[a-zA-Z]+\\)[[:space:]]+" 1 font-lock-variable-name-face)
    ("\\(true\\|false\\)" 1 font-lock-constant-face)
    ("(\\(select\\)[[:space:]]+[^[:space:]]+[[:space:]]+\\(from\\)\\>"
     (1 font-lock-constant-face)
     (2 font-lock-constant-face))
    ,(eval-when-compile
       (dune--field-vals "kind" "normal" "ppx_rewriter" "ppx_deriver"))
    ,(eval-when-compile
       (dune--field-vals "mode" "standard" "fallback" "promote"
                                "promote-until-clean"))
    (,(concat "(" dune-builtin-regex) 1 font-lock-builtin-face)
    ("(preprocess[[:space:]]+(\\(pps\\)" 1 font-lock-builtin-face)
    ("(name +\\(runtest\\))" 1 font-lock-builtin-face)
    (,(eval-when-compile
        (concat "(" (regexp-opt '("fallback") t)))
     1 dune-error-face)))

(defvar dune-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\; "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table)
  "dune syntax table.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                             SMIE

(require 'smie)

(defvar dune-smie-grammar
  (when (fboundp 'smie-prec2->grammar)
    (smie-prec2->grammar
     (smie-bnf->prec2 '()))))

(defun dune-smie-rules (kind token)
  (cond
   ((eq kind :close-all) '(column . 0))
   ((and (eq kind :after) (equal token ")"))
    (save-excursion
      (goto-char (cadr (smie-indent--parent)))
      (if (looking-at-p dune-stanzas-regex)
          '(column . 0)
        1)))
   ((eq kind :before)
    (if (smie-rule-parent-p "(")
        (save-excursion
          (goto-char (cadr (smie-indent--parent)))
          (cond
           ((looking-at-p dune-stanzas-regex) 1)
           ((looking-at-p dune-fields-regex)
            (smie-rule-parent 0))
           ((smie-rule-sibling-p) (cons 'column (current-column)))
           (t (cons 'column (current-column)))))
      '(column . 0)))
   ((eq kind :list-intro)
    nil)
   (t 1)))

(defun verbose-dune-smie-rules (kind token)
  (let ((value (dune-smie-rules kind token)))
    (message
     "%s '%s'; sibling-p:%s parent:%s hanging:%s = %s"
     kind token
     (ignore-errors (smie-rule-sibling-p))
     (ignore-errors smie--parent)
     (ignore-errors (smie-rule-hanging-p))
     value)
    value))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                          Skeletons
;; See Info node "Autotype".

(define-skeleton dune-insert-library-form
  "Insert a library stanza."
  nil
  "(library" > \n
  "(name        " _ ")" > \n
  "(public_name " _ ")" > \n
  "(libraries   " _ ")" > \n
  "(synopsis \"" _ "\"))" > ?\n)

(define-skeleton dune-insert-executable-form
  "Insert an executable stanza."
  nil
  "(executable" > \n
  "(name        " _ ")" > \n
  "(public_name " _ ")" > \n
  "(modules     " _ ")" > \n
  "(libraries   " _ "))" > ?\n)

(define-skeleton dune-insert-executables-form
  "Insert an executables stanza."
  nil
  "(executables" > \n
  "(names        " _ ")" > \n
  "(public_names " _ ")" > \n
  "(libraries    " _ "))" > ?\n)

(define-skeleton dune-insert-rule-form
  "Insert a rule stanza."
  nil
  "(rule" > \n
  "(targets " _ ")" > \n
  "(deps    " _ ")" > \n
  "(action  (" _ ")))" > ?\n)

(define-skeleton dune-insert-ocamllex-form
  "Insert an ocamllex stanza."
  nil
  "(ocamllex (" _ "))" > ?\n)

(define-skeleton dune-insert-ocamlyacc-form
  "Insert an ocamlyacc stanza."
  nil
  "(ocamlyacc (" _ "))" > ?\n)

(define-skeleton dune-insert-menhir-form
  "Insert a menhir stanza."
  nil
  "(menhir" > \n
  "((modules (" _ "))))" > ?\n)

(define-skeleton dune-insert-alias-form
  "Insert an alias stanza."
  nil
  "(alias" > \n
  "(name " _ ")" > \n
  "(deps " _ "))" > ?\n)

(define-skeleton dune-insert-install-form
  "Insert an install stanza."
  nil
  "(install" > \n
  "(section " _ ")" > \n
  "(files   " _ "))" > ?\n)

(define-skeleton dune-insert-copyfiles-form
  "Insert a copy_files stanza."
  nil
  "(copy_files " _ ")" > ?\n)

(define-skeleton dune-insert-test-form
  "Insert a test stanza."
  nil
  "(test" > \n
  "(name " _ "))" > ?\n)

(define-skeleton dune-insert-tests-form
  "Insert a tests stanza."
  nil
  "(tests" > \n
  "(names " _ "))" > ?\n)

(define-skeleton dune-insert-env-form
  "Insert a env stanza."
  nil
  "(env" > \n
  "(" _ " " _ "))" > ?\n)

(define-skeleton dune-insert-ignored-subdirs-form
  "Insert a ignored_subdirs stanza."
  nil
  "(ignored_subdirs (" _ "))" > ?\n)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar dune-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-c" 'compile)
    (define-key map "\C-c.l" 'dune-insert-library-form)
    (define-key map "\C-c.e" 'dune-insert-executable-form)
    (define-key map "\C-c.x" 'dune-insert-executables-form)
    (define-key map "\C-c.r" 'dune-insert-rule-form)
    (define-key map "\C-c.p" 'dune-insert-ocamllex-form)
    (define-key map "\C-c.y" 'dune-insert-ocamlyacc-form)
    (define-key map "\C-c.m" 'dune-insert-menhir-form)
    (define-key map "\C-c.a" 'dune-insert-alias-form)
    (define-key map "\C-c.i" 'dune-insert-install-form)
    (define-key map "\C-c.c" 'dune-insert-copyfiles-form)
    (define-key map "\C-c.t" 'dune-insert-tests-form)
    (define-key map "\C-c.v" 'dune-insert-env-form)
    (define-key map "\C-c.d" 'dune-insert-ignored-subdirs-form)
    map)
  "Keymap used in dune mode.")

(defun dune-build-menu ()
  (easy-menu-define
    dune-mode-menu  (list dune-mode-map)
    "dune mode menu."
    '("Dune/jbuild"
      ("Stanzas"
       ["library" dune-insert-library-form t]
       ["executable" dune-insert-executable-form t]
       ["executables" dune-insert-executables-form t]
       ["rule" dune-insert-rule-form t]
       ["alias" dune-insert-alias-form t]
       ["ocamllex" dune-insert-ocamllex-form t]
       ["ocamlyacc" dune-insert-ocamlyacc-form t]
       ["menhir" dune-insert-menhir-form t]
       ["install" dune-insert-install-form t]
       ["copy_files" dune-insert-copyfiles-form t]
       ["test" dune-insert-test-form t]
       ["env" dune-insert-env-form t]
       ["ignored_subdirs" dune-insert-ignored-subdirs-form t]
       )))
  (easy-menu-add dune-mode-menu))


;;;###autoload
(define-derived-mode dune-mode prog-mode "dune"
  "Major mode to edit dune files.
For customization purposes, use `dune-mode-hook'."
  (setq-local font-lock-defaults '(dune-font-lock-keywords))
  (setq-local comment-start ";")
  (setq-local comment-end "")
  (setq indent-tabs-mode nil)
  (setq-local require-final-newline mode-require-final-newline)
  (smie-setup dune-smie-grammar #'dune-smie-rules)
  (dune-build-menu))


;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\(?:\\`\\|/\\)dune\\(?:\\.inc\\)?\\'" . dune-mode))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                     Interacting with dune

(defcustom dune-command "dune"
  "The dune command."
  :type 'string)

;;;###autoload
(defun dune-promote ()
  "Promote the correction for the current file."
  (interactive)
  (if (buffer-modified-p)
      (error "Cannot promote as buffer is modified")
    (shell-command
     (format "%s promote %s"
             dune-command
             (file-name-nondirectory (buffer-file-name))))
    (revert-buffer nil t)))

;;;###autoload
(defun dune-runtest-and-promote ()
  "Run tests in the current directory and promote the current buffer."
  (interactive)
  (compile (format "%s build @@runtest" dune-command))
  (dune-promote))

(provide 'dune)

;;; dune.el ends here
