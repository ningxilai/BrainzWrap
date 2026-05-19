;;; test-runner.el --- Load stubs and run bookbrainz tests  -*- lexical-binding: t; -*-

;; Provide minimal stubs for vui/vui-components so we can test
;; pure functions in bookbrainz.el without a full Emacs session.

(require 'ert)
(require 'cl-lib)

;; Stub: provide the packages that bookbrainz.el requires
(provide 'vui)
(provide 'vui-components)

;; Minimal vui-defcomponent stub
(defmacro vui-defcomponent (name args &rest body)
  (declare (indent defun))
  nil)

;; Minimal vui-component stub
(defun vui-component (&rest _args) nil)

;; Stub vui layout helpers
(defun vui-vstack (&rest _args) nil)
(defun vui-hstack (&rest _args) nil)
(defun vui-text (&rest _args) nil)
(defun vui-heading-1 (&rest _args) nil)
(defun vui-button (&rest _args) nil)
(defun vui-field (&rest _args) nil)
(defun vui-list (&rest _args) nil)
(defun vui-newline (&rest _args) nil)
(defun vui-muted (&rest _args) nil)
(defun vui-error (&rest _args) nil)
(defun vui-collapsible (&rest _args) nil)
(defun vui-set-state (&rest _args) nil)
(defun vui-async-callback (&rest _args) nil)
(defun vui-mount (&rest _args) nil)

;; Stub vui-mode
(define-derived-mode vui-mode nil "VUI" "Stub")

;; Stub url utilities
(defun url-build-query-string (params)
  (mapconcat (pcase-lambda (`(,k . ,v))
               (format "%s=%s" k v))
             params "&"))

;; Stub browse-url
(defun browse-url (&rest _args) nil)

;; Stub org-mode
(defun org-mode () nil)

;; Stub timer
(defun timerp (_) nil)

;; Stub quit-window
(defun quit-window (&rest _args) nil)

;; Now load bookbrainz.el
(let ((load-path (cons (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
                       load-path)))
  (require 'bookbrainz))

;; Load the actual test file
(load-file (expand-file-name "bookbrainz-test.el"
                              (file-name-directory (or load-file-name buffer-file-name))))
