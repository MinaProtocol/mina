;;; dune-flymake.el --- Flymake support for dune files   -*- coding: utf-8 -*-

;; Copyright (C) 2017- Christophe Troestler

;; This file is not part of GNU Emacs.

;; Permission to use, copy, modify, and distribute this software for
;; any purpose with or without fee is hereby granted, provided that
;; the above copyright notice and this permission notice appear in
;; all copies.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
;; WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
;; AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
;; CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
;; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
;; NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
;; CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

(require 'flymake)
(require 'dune)

(defvar dune-flymake-temporary-file-directory
  (expand-file-name "dune" temporary-file-directory)
  "Directory where to duplicate the files for flymake.")

(defvar dune-program
  (expand-file-name "dune-lint" dune-flymake-temporary-file-directory)
  "Script to use to check the dune file.")

(defvar dune--allowed-file-name-masks
  '("\\(?:\\`\\|/\\)dune\\'" dune-flymake-init
    dune-flymake-cleanup)
  "Flymake entry for dune files.  See `flymake-allowed-file-name-masks'.")

(defvar dune--err-line-patterns
  ;; Beware that the path from the root will be reported by dune
  ;; but flymake requires it to match the file name.
  '(("File \"[^\"]*\\(dune\\)\", line \\([0-9]+\\), \
characters \\([0-9]+\\)-\\([0-9]+\\): +\\([^\n]*\\)$"
     1 2 3 5))
  "Value of `flymake-err-line-patterns' for dune files.")

(defun dune-flymake-create-lint-script ()
  "Create the lint script if it does not exist. This is nedded as long as See
https://github.com/ocaml/dune/issues/241 is not fixed."
  (unless (file-exists-p dune-program)
    (let ((dir (file-name-directory dune-program))
          (pgm "#!/usr/bin/env ocaml
;;
#load \"unix.cma\";;
#load \"str.cma\";;

open Printf

let filename = Sys.argv.(1)
let root = try Some(Sys.argv.(2)) with _ -> None

let read_all fh =
  let buf = Buffer.create 1024 in
  let b = Bytes.create 1024 in
  let len = ref 0 in
  while len := input fh b 0 1024; !len > 0 do
    Buffer.add_subbytes buf b 0 !len
  done;
  Buffer.contents buf

let errors =
  let root = match root with
    | None | Some \"\" -> \"\"
    | Some r -> \"--root=\" ^ Filename.quote r in
  let cmd = sprintf \"dune external-lib-deps %s %s\" root
              (Filename.quote (Filename.basename filename)) in
  let env = Unix.environment() in
  let (_,_,fh) as p = Unix.open_process_full cmd env in
  let out = read_all fh in
  match Unix.close_process_full p with
  | Unix.WEXITED (0|1) ->
     (* dune will normally exit with 1 as it will not be able to
        perform the requested action. *)
     out
  | Unix.WEXITED 127 -> printf \"dune not found in path.\\n\"; exit 1
  | Unix.WEXITED n -> printf \"dune exited with status %d.\\n\" n; exit 1
  | Unix.WSIGNALED n -> printf \"dune was killed by signal %d.\\n\" n;
                        exit 1
  | Unix.WSTOPPED n -> printf \"dune was stopped by signal %d\\n.\" n;
                       exit 1


let () =
  let re = \"\\\\(:?\\\\)[\\r\\n]+\\\\([a-zA-Z]+\\\\)\" in
  let errors = Str.global_substitute (Str.regexp re)
                 (fun s -> let colon = Str.matched_group 1 s = \":\" in
                           let f = Str.matched_group 2 s in
                           if f = \"File\" then \"\\n File\"
                           else if colon then \": \" ^ f
                           else \", \" ^ f)
                 errors in
  print_string errors"))
      (make-directory dir t)
      (append-to-file pgm nil dune-program)
      (set-file-modes dune-program #o777)
      )))

(defun dune--temp-name (absolute-path)
  "Full path of the copy of the filename in
`dune-flymake-temporary-file-directory'."
  (let ((slash-pos (string-match "/" absolute-path)))
    (file-truename (expand-file-name (substring absolute-path (1+ slash-pos))
                                     dune-flymake-temporary-file-directory))))

(defun dune-flymake-create-temp (filename _prefix)
  ;; based on `flymake-create-temp-with-folder-structure'.
  (unless (stringp filename)
    (error "Invalid filename"))
  (dune--temp-name filename))

(defun dune--opam-files (dir)
  "Return all opam files in the directory DIR."
  (let ((files nil))
    (dolist (f (directory-files-and-attributes dir t ".*\\.opam\\'"))
      (when (null (cadr f))
        (push (car f) files)))
    files))

(defun dune--root (filename)
  "Return the root and copy the necessary context files for dune."
  ;; FIXME: the root depends on dune-project.  If none is found,
  ;; assume the commands are issued from the dir where opam files are found.
  (let* ((dir (locate-dominating-file (file-name-directory filename)
                                      #'dune--opam-files)))
    (when dir
      (setq dir (expand-file-name dir)); In case it is ~/...
      (make-directory (dune--temp-name dir) t)
      (dolist (f (dune--opam-files dir))
        (copy-file f (dune--temp-name f) t)))
    dir))

(defun dune--delete-opam-files (dir)
  "Delete all opam files in the directory DIR."
  (dolist (f (dune--opam-files dir))
    (flymake-safe-delete-file f)))

(defun dune-flymake-cleanup ()
  "Attempt to delete temp dir created by `dune-flymake-create-temp', do not fail on error."
  (let ((dir (file-name-directory flymake-temp-source-file-name))
        (temp-dir (concat (directory-file-name
                           dune-flymake-temporary-file-directory) "/")))
    (flymake-log 3 "Clean up %s" flymake-temp-source-file-name)
    (flymake-safe-delete-file flymake-temp-source-file-name)
    (condition-case nil
        (delete-directory (expand-file-name "_build" dir) t)
      (error nil))
    ;; Also delete parent dirs if empty or only contain opam files
    (while (and (not (string-equal dir temp-dir))
                (> (length dir) 0))
      (condition-case nil
          (progn
            (dune--delete-opam-files dir)
            (delete-directory dir)
            (setq dir (file-name-directory (directory-file-name dir))))
        (error ; then top the loop
         (setq dir ""))))))

(defun dune-flymake-init ()
  (dune-flymake-create-lint-script)
  (let ((fname (flymake-init-create-temp-buffer-copy
                'dune-flymake-create-temp))
        (root (or (dune--root buffer-file-name) "")))
    (list dune-program (list fname root))))

(defun dune-flymake-dune-mode-hook ()
  (push dune--allowed-file-name-masks flymake-allowed-file-name-masks)
  (setq-local flymake-err-line-patterns dune--err-line-patterns))

(provide 'dune-flymake)
