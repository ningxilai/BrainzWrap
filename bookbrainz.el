;;; bookbrainz.el --- BookBrainz API client for Emacs  -*- lexical-binding: t; -*-

;; Author: opencode
;; Keywords: query , bookbrainz
;; URL: https://github.com/ningxilai/BrainzWrap
;; Package-Requires: ((emacs "29.1") (vui "1.0.0"))
;; SPDX-License-Identifier: CC0-1.0

;; To the extent possible under law, the author has waived all
;; copyright and related or neighboring rights to this work.

;;; Commentary:

;; BookBrainz API client with VUI frontend.

;; Quick start:
;;   (use-package bookbrainz
;;     :vc (:url "https://github.com/ningxilai/BrainzWrap"))
;;   M-x bookbrainz-search

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)
(require 'url)
(require 'vui)
(require 'vui-components)


;;; Custom variables

(defgroup bookbrainz nil
  "BookBrainz API client."
  :group 'external
  :prefix "bookbrainz-")

(defcustom bookbrainz-api-base "https://api.bookbrainz.org/1"
  "Base URL for the BookBrainz API."
  :type 'string
  :group 'bookbrainz)

(defcustom bookbrainz-user-agent "Emacs-BookBrainz/1.0 (bookbrainz.el)"
  "User-agent string for BookBrainz API requests."
  :type 'string
  :group 'bookbrainz)

(defcustom bookbrainz-page-size 20
  "Number of results per page."
  :type 'integer
  :group 'bookbrainz)

(defcustom bookbrainz-org-dir "bookbrainz"
  "Subdirectory under `org-directory' for saved BookBrainz entities."
  :type 'string
  :group 'bookbrainz)

(defcustom bookbrainz-rate-limit '(1 . 1)
  "Rate limit (requests per second)."
  :type '(cons integer integer)
  :group 'bookbrainz)


;;; EIEIO class hierarchy

(defclass bb-entity ()
  ((type :initarg :type :reader bb-type)
   (bbid :initarg :bbid :reader bb-bbid)
   (data :initarg :data :reader bb-data))
  "Base EIEIO class wrapping a BookBrainz API alist.")

(defclass bb-author (bb-entity) ())
(defclass bb-publisher (bb-entity) ())
(defclass bb-series (bb-entity) ())
(defclass bb-work (bb-entity) ())
(defclass bb-edition-group (bb-entity) ())
(defclass bb-edition (bb-entity) ())

(defun bb-entity-create (type bbid data)
  "Wrap DATA alist in an EIEIO object for entity TYPE."
  (let ((class (intern-soft (format "bb-%s" type))))
    (if (and class (find-class class))
        (make-instance class :type type :bbid bbid :data data)
      (make-instance 'bb-entity :type type :bbid bbid :data data))))

(cl-defgeneric bb-name (entity)
  "Return display name for ENTITY.")
(cl-defmethod bb-name ((e bb-entity))
  (bookbrainz--entity-name (bb-data e)))

(cl-defgeneric bb-detail (entity)
  "Return VUI vnodes for ENTITY's detail view.")
(cl-defmethod bb-detail ((_e bb-entity))
  (vui-muted "Detail view not available for this entity type"))

(cl-defgeneric bb-format-result (entity)
  "Return a detail string for ENTITY in search results.")
(cl-defmethod bb-format-result ((_e bb-entity)) "")

(cl-defgeneric bb-org-props (entity &optional json-ld)
  "Return Org :PROPERTIES: drawer string for ENTITY.")
(cl-defmethod bb-org-props ((e bb-entity) &optional _json-ld)
  (let* ((data (bb-data e))
         (props (list (format ":ID:          %s" (or (alist-get 'bbid data) ""))
                      (format ":ENTITY_TYPE: %s" (bb-type e))
                      (format ":NAME:        %s" (bb-name e)))))
    (when-let* ((disambig (alist-get 'disambiguation data)))
      (push (format ":DESC:        %s" disambig) props))
    (concat ":PROPERTIES:\n"
            (mapconcat #'identity (nreverse props) "\n")
            "\n:END:")))

(defmacro bb-let* (data bindings &rest body)
  "Like `let*', but binds each VAR to (alist-get \\='KEY DATA).
Each BINDING is (VAR KEY) with KEY quoted automatically.
If KEY is omitted, VAR is used as the key.
BODY is evaluated with VARs bound.

\(fn DATA ((VAR KEY) ...) &rest BODY)"
  (declare (indent 2))
  `(let* ,(mapcar (lambda (b)
                    (if (consp b)
                        `(,(car b) (alist-get ',(or (cadr b) (car b)) ,data))
                      `(,b (alist-get ',b ,data))))
                  bindings)
     ,@body))

(defmacro bb-when-let* (data bindings &rest body)
  "Like `when-let*' with automatic `alist-get' from DATA.
Each BINDING is (VAR KEY) with KEY quoted automatically.
If KEY is omitted, VAR is used as the key.
BODY is evaluated if all bindings are non-nil.

\(fn DATA ((VAR KEY) ...) &rest BODY)"
  (declare (indent 2))
  `(when-let* ,(mapcar (lambda (b)
                          (if (consp b)
                              `(,(car b) (alist-get ',(or (cadr b) (car b)) ,data))
                            `(,b (alist-get ',b ,data))))
                        bindings)
     ,@body))


;;; Rate-limited API client

(defvar bookbrainz--request-log nil
  "List of timestamps for sliding-window rate limiting.")

(defun bookbrainz--wait-if-needed ()
  (let* ((limits bookbrainz-rate-limit)
         (max-req (car limits))
         (period (cdr limits))
         (now (float-time)))
    (setq bookbrainz--request-log
          (seq-filter (lambda (ts) (>= ts (- now period)))
                      bookbrainz--request-log))
    (when (>= (length bookbrainz--request-log) max-req)
      (let* ((oldest (car (last bookbrainz--request-log)))
             (wait (- (+ oldest period) (float-time))))
        (when (> wait 0)
          (sleep-for wait))
        (setq bookbrainz--request-log
              (seq-filter (lambda (ts) (>= ts (- (float-time) period)))
                          bookbrainz--request-log))))
    (push now bookbrainz--request-log)))

(defun bookbrainz--api-request (rel-url &optional params)
  (bookbrainz--wait-if-needed)
  (let* ((url-request-method "GET")
         (url-mime-accept-string "application/json")
         (url-user-agent bookbrainz-user-agent)
         (query `(,@params))
         (url (concat bookbrainz-api-base rel-url
                      (if query (concat "?" (url-build-query-string query)) "")))
         (buf (url-retrieve-synchronously url)))
    (when buf
      (with-current-buffer buf
        (goto-char (point-min))
        (re-search-forward "^$" nil t)
        (set-buffer-multibyte t)
        (decode-coding-region (point) (point-max) 'utf-8)
        (let ((json-array-type 'list)
              (json-object-type 'alist)
              (json-key-type 'symbol)
              (json-false nil))
          (condition-case err
              (json-read)
            (error
             (warn "BookBrainz API error: %s" err)
             nil)))))))


;;; Search & lookup

(defun bookbrainz--search (entity-type query &optional size from)
  (let ((params `(("q" ,query)
                  ("type" ,entity-type)
                  ("size" ,(number-to-string (or size bookbrainz-page-size)))
                  ("from" ,(number-to-string (or from 0))))))
    (bookbrainz--api-request "/search" params)))

(defun bookbrainz--lookup (entity-type bbid)
  (bookbrainz--api-request (format "/%s/%s" entity-type bbid)))


;;; Entity name

(defun bookbrainz--entity-name (entity)
  (or (alist-get 'name entity)
      (let ((alias (alist-get 'defaultAlias entity)))
        (and alias (alist-get 'name alias)))
      "(untitled)"))

(defun bookbrainz--entity-type-label (type)
  (pcase type
    ("author" "Author")
    ("publisher" "Publisher")
    ("series" "Book Series")
    ("work" "Book Work")
    ("edition-group" "Edition Group")
    ("edition" "Edition")
    ("area" "Area")
    ("collection" "Collection")
    ("editor" "Editor")
    (_ (concat (upcase (substring type 0 1)) (substring type 1)))))

(defvar bookbrainz--entity-types-no-api
  '("area" "collection" "editor")
  "Entity types that are searchable via the API but have no detail lookup endpoint.
`editor' has no BBID in search results; `area' and `collection' have BBIDs
but no API lookup.  For these types, search results return basic info but
full entity detail must be viewed on bookbrainz.org in a browser.")

(defun bookbrainz--entity-type-has-api-p (type)
  "Return non-nil if TYPE has a lookup API endpoint."
  (not (member type bookbrainz--entity-types-no-api)))


;;; Detail views

(defun bookbrainz--meta (label value)
  (when value
    (vui-hstack
     (vui-text (format " %s:" label) :face 'bold :width 16)
     (vui-text (format "%s" value)))))

(defun bookbrainz--format-date (date-str)
  "Strip ISO 8601 extended format prefix from BookBrainz dates.
E.g. \"+001954-07-29\" -> \"1954-07-29\", \"+001974\" -> \"1974\"."
  (when date-str
    (replace-regexp-in-string (rx string-start (+ (any "+0"))) "" date-str)))

(defun bookbrainz--ended-label (ended)
  (when ended
    (vui-text " (ended)" :face 'warning)))

(defun bookbrainz--format-publishers (publishers)
  (when publishers
    (mapconcat (lambda (p) (or (alist-get 'name p) "")) publishers ", ")))

(defun bookbrainz--format-author-credits (credits)
  (let ((names (alist-get 'names credits)))
    (when names
      (mapconcat (lambda (n) (or (alist-get 'name n) "")) names ", "))))

(defun bookbrainz--format-author (a)
  (let ((name (bookbrainz--entity-name a))
        (type (alist-get 'authorType a)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun bookbrainz--format-publisher (p)
  (let ((name (bookbrainz--entity-name p))
        (type (alist-get 'publisherType p)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun bookbrainz--format-series (s)
  (let ((name (bookbrainz--entity-name s))
        (type (alist-get 'seriesType s)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun bookbrainz--format-work (w)
  (let ((name (bookbrainz--entity-name w))
        (type (alist-get 'workType w)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun bookbrainz--format-edition-group (eg)
  (let ((name (bookbrainz--entity-name eg))
        (type (alist-get 'editionGroupType eg)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun bookbrainz--format-edition (e)
  (let ((name (bookbrainz--entity-name e))
        (date (bookbrainz--format-date (alist-get 'releaseEventDate e)))
        (fmt (alist-get 'editionFormat e)))
    (string-join
     (delq nil
           (list name
                 (when date (format "(%s)" date))
                 (when fmt (format "[%s]" fmt))))
     " ")))


;;; Generic dispatch methods

(cl-defmethod bb-detail ((e bb-author))
  (bookbrainz--author-detail (bb-data e)))
(cl-defmethod bb-detail ((e bb-publisher))
  (bookbrainz--publisher-detail (bb-data e)))
(cl-defmethod bb-detail ((e bb-series))
  (bookbrainz--series-detail (bb-data e)))
(cl-defmethod bb-detail ((e bb-work))
  (bookbrainz--work-detail (bb-data e)))
(cl-defmethod bb-detail ((e bb-edition-group))
  (bookbrainz--edition-group-detail (bb-data e)))
(cl-defmethod bb-detail ((e bb-edition))
  (bookbrainz--edition-detail (bb-data e)))

(cl-defmethod bb-format-result ((e bb-author))
  (bookbrainz--format-author (bb-data e)))
(cl-defmethod bb-format-result ((e bb-publisher))
  (bookbrainz--format-publisher (bb-data e)))
(cl-defmethod bb-format-result ((e bb-series))
  (bookbrainz--format-series (bb-data e)))
(cl-defmethod bb-format-result ((e bb-work))
  (bookbrainz--format-work (bb-data e)))
(cl-defmethod bb-format-result ((e bb-edition-group))
  (bookbrainz--format-edition-group (bb-data e)))
(cl-defmethod bb-format-result ((e bb-edition))
  (bookbrainz--format-edition (bb-data e)))


;;; Detail view functions

(defun bookbrainz--author-detail (entity)
  (vui-vstack :spacing 0
    (let ((ended (alist-get 'ended entity)))
      (vui-hstack
        (bookbrainz--meta "Author Type" (alist-get 'authorType entity))
        (bookbrainz--ended-label ended)))
    (bookbrainz--meta "Gender" (alist-get 'gender entity))
    (bookbrainz--meta "Begin Area" (alist-get 'beginArea entity))
    (bookbrainz--meta "Begin Date" (bookbrainz--format-date (alist-get 'beginDate entity)))
    (bookbrainz--meta "End Area" (alist-get 'endArea entity))
    (bookbrainz--meta "End Date" (bookbrainz--format-date (alist-get 'endDate entity)))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

(defun bookbrainz--publisher-detail (entity)
  (vui-vstack :spacing 0
    (let ((ended (alist-get 'ended entity)))
      (vui-hstack
        (bookbrainz--meta "Publisher Type" (alist-get 'publisherType entity))
        (bookbrainz--ended-label ended)))
    (bookbrainz--meta "Area" (alist-get 'area entity))
    (bookbrainz--meta "Begin Date" (bookbrainz--format-date (alist-get 'beginDate entity)))
    (bookbrainz--meta "End Date" (bookbrainz--format-date (alist-get 'endDate entity)))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

(defun bookbrainz--series-detail (entity)
  (vui-vstack :spacing 0
    (bookbrainz--meta "Series Type" (alist-get 'seriesType entity))
    (bookbrainz--meta "Ordering Type" (alist-get 'seriesOrderingType entity))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

(defun bookbrainz--work-detail (entity)
  (vui-vstack :spacing 0
    (bookbrainz--meta "Work Type" (alist-get 'workType entity))
    (let ((langs (alist-get 'languages entity)))
      (when langs
        (bookbrainz--meta "Languages" (string-join langs ", "))))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

(defun bookbrainz--edition-group-detail (entity)
  (vui-vstack :spacing 0
    (bookbrainz--meta "Edition Group Type" (alist-get 'editionGroupType entity))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

(defun bookbrainz--edition-detail (entity)
  (vui-vstack :spacing 0
    (bookbrainz--meta "Edition Format" (alist-get 'editionFormat entity))
    (bookbrainz--meta "Status" (alist-get 'status entity))
    (bookbrainz--meta "Release Date" (bookbrainz--format-date (alist-get 'releaseEventDate entity)))
    (bookbrainz--meta "Pages" (alist-get 'pages entity))
    (bookbrainz--meta "Depth" (alist-get 'depth entity))
    (bookbrainz--meta "Height" (alist-get 'height entity))
    (bookbrainz--meta "Width" (alist-get 'width entity))
    (bookbrainz--meta "Weight" (alist-get 'weight entity))
    (let ((langs (alist-get 'languages entity)))
      (when langs
        (bookbrainz--meta "Languages" (string-join langs ", "))))
    (let ((pubs (bookbrainz--format-publishers (alist-get 'publishers entity))))
      (when pubs
        (bookbrainz--meta "Publishers" pubs)))
    (let ((ac (bookbrainz--format-author-credits (alist-get 'authorCredits entity))))
      (when ac
        (bookbrainz--meta "Author Credits" ac)))
    (bookbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))))

 
;;; Section display helpers

(defun bookbrainz--entity-data-fields (data &optional skip-keys)
  "Return vui children for key-value pairs in alist DATA.
Skips keys in SKIP-KEYS. Uses `vui-collapsible' for nested structures."
  (let ((result nil))
    (dolist (pair data (nreverse result))
      (let ((k (car pair))
            (v (cdr pair)))
        (when (and v (not (memq k (or skip-keys '(bbid))))
                   (or (not (stringp v)) (not (string-empty-p v))))
          (setq result
                (nconc result
                       (cond
                        ((stringp v)
                         (list (bookbrainz--meta (format "%s" k) v)))
                        ((and (listp v) (consp (car v)))
                         (if (consp (caar v))
                             (let ((names (delq nil
                                               (mapcar (lambda (item)
                                                         (or (alist-get 'name item)
                                                             (alist-get 'value item)
                                                             (alist-get 'label item)
                                                             (when (stringp (car item))
                                                               (cdr item))))
                                                       v))))
                               (list (bookbrainz--meta (format "%s" k)
                                                       (mapconcat #'identity names ", "))))
                           (let ((name (or (alist-get 'name v) (alist-get 'label v))))
                             (if name
                                 (list (bookbrainz--meta (format "%s" k) (format "%s" name)))
                               (list
                                (vui-collapsible :title (format "%s" k) :key k
                                  (apply #'vui-vstack :spacing 0
                                         (delq nil
                                               (mapcar (lambda (sv-pair)
                                                         (let ((sk (car sv-pair))
                                                               (sv (cdr sv-pair)))
                                                           (when (and sv (or (not (stringp sv))
                                                                              (not (string-empty-p sv))))
                                                             (bookbrainz--meta (format "%s" sk)
                                                                               (if (stringp sv) sv
                                                                                 (format "%s" sv))))))
                                                       v)))))))))
                        ((listp v)
                         (list (bookbrainz--meta (format "%s" k)
                                                 (mapconcat (lambda (x) (format "%s" x)) v ", "))))
                        (t
                         (list (bookbrainz--meta (format "%s" k) (format "%s" v))))))))))))

(defun bookbrainz--aliases-section (aliases)
  "Render collapsible Aliases section.
ALIASES is a list of alist items with `name', `sortName', `language', `primary'."
  (vui-collapsible :title (format "Aliases (%d)" (length aliases))
    (apply #'vui-vstack :spacing 0
           (mapcar (lambda (a)
                     (let ((name (or (alist-get 'name a) "(unnamed)"))
                           (lang (alist-get 'language a))
                           (primary (alist-get 'primary a))
                           (sort (alist-get 'sortName a)))
                        (vui-hstack
                          (vui-text (format " %s" name))
                          (when lang
                            (vui-text (format " (%s%s)" lang (if primary " *" ""))
                                      :face 'shadow))
                         (when (and sort (not (equal sort name)))
                           (vui-text (format " [%s]" sort) :face 'shadow)))))
                   aliases))))

(defun bookbrainz--identifiers-section (identifiers)
  "Render collapsible Identifiers section.
IDENTIFIERS is a list of alist items with `type' and `value'."
  (vui-collapsible :title (format "Identifiers (%d)" (length identifiers))
    (apply #'vui-vstack :spacing 0
           (mapcar (lambda (id)
                     (let ((type (alist-get 'type id))
                           (value (alist-get 'value id)))
                       (bookbrainz--meta (or type "(unknown)") (or value ""))))
                   identifiers))))

(defun bookbrainz--load-relationship-names (relationships page page-size)
  "Load display names for relationships on PAGE, caching in VUI state.
Fires up to PAGE-SIZE lookups staggered by idle timers."
  (let* ((start (* (1- page) page-size))
         (page-rels (seq-subseq relationships start
                               (min (+ start page-size) (length relationships))))
         (delay 0.0))
    (dolist (r page-rels)
      (let* ((bbid (alist-get 'targetBbid r))
             (type (alist-get 'targetEntityType r)))
        (when (and bbid type)
          (setq delay (+ delay 0.05))
          (run-with-idle-timer delay nil
            (vui-with-async-context
             (condition-case err
                  (let ((data (bookbrainz--lookup type bbid)))
                    (when data
                      (let ((name (or (alist-get 'name (alist-get 'defaultAlias data))
                                      (alist-get 'name data)
                                      bbid)))
                        (vui-set-state :relationship-names
                          (lambda (old)
                            (cons (cons bbid name)
                                  (cl-remove bbid old :key #'car
                                              :test #'equal)))))))
                (error
                 (message "Failed to load name for %s/%s: %s" type bbid err))))))))))

(defun bookbrainz--relationships-section
    (relationships page page-size-page relationship-names on-page-change)
  "Render collapsible Relationships section with pagination.
PAGE is current page (1-indexed).  PAGE-SIZE-PAGE is items per page.
RELATIONSHIP-NAMES is an alist of (bbid . name).
ON-PAGE-CHANGE is a one-arg function called with the new page number."
  (let* ((total (length relationships))
         (total-pages (max 1 (ceiling total page-size-page)))
         (start (* (1- page) page-size-page))
         (page-rels (seq-subseq relationships start
                               (min (+ start page-size-page) total))))
    (vui-collapsible :title (format "Relationships (%d)" total)
      (apply #'vui-vstack :spacing 0
             (mapcar (lambda (r)
                       (let* ((type (or (alist-get 'relationshipTypeName r) "(unknown)"))
                              (target (or (alist-get 'targetBbid r) ""))
                              (target-type (or (alist-get 'targetEntityType r) ""))
                              (phrase (or (alist-get 'linkPhrase r) ""))
                              (display-name (alist-get target relationship-names
                                                       nil nil #'equal))
                              (label (or display-name
                                         (if (string-empty-p target) "(no target)"
                                           (substring target 0 8)))))
                         (vui-hstack
                           (vui-text (format " %s:" type) :face 'bold :width 16)
                           (vui-button label
                             :on-click (lambda ()
                                         (unless (string-empty-p target)
                                           (bookbrainz-open-entity target-type target))))
                           (vui-text (format " %s" phrase) :face 'shadow))))
                     page-rels)
             (when (> total-pages 1)
               (list
                (vui-hstack
                 (when (> page 1)
                   (vui-button "[Prev]"
                     :on-click (lambda () (funcall on-page-change (1- page)))))
                 (vui-text (format "Page %d/%d" page total-pages) :face 'shadow)
                 (when (< page total-pages)
                   (vui-button "[Next]"
                     :on-click (lambda () (funcall on-page-change (1+ page))))))))))))


;;; Async entity loading

(defun bookbrainz--load-entity-async (entity-type bbid on-success on-error)
  "Load ENTITY-TYPE entity with BBID asynchronously.
ON-SUCCESS is called with (entity) on success.
ON-ERROR is called with (error-condition) on failure.
Returns the timer object.
Callbacks should be created with `vui-async-callback' or `vui-with-async-context'."
  (run-with-idle-timer
   0.1 nil
   (lambda ()
     (condition-case err
         (let* ((entity (bookbrainz--lookup entity-type bbid)))
           (funcall on-success entity))
        (error
         (funcall on-error err))))))

(defun bookbrainz--load-aliases-async (entity-type bbid)
  "Fetch aliases for ENTITY-TYPE entity with BBID."
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case err
        (let* ((response (bookbrainz--api-request
                          (format "/%s/%s/aliases" entity-type bbid)))
               (aliases (alist-get 'aliases response)))
          (when aliases
            (vui-set-state :aliases aliases)))
      (error
       (message "BookBrainz aliases error: %s" (error-message-string err)))))))

(defun bookbrainz--load-identifiers-async (entity-type bbid)
  "Fetch identifiers for ENTITY-TYPE entity with BBID."
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case err
        (let* ((response (bookbrainz--api-request
                          (format "/%s/%s/identifiers" entity-type bbid)))
               (identifiers (alist-get 'identifiers response)))
          (when identifiers
            (vui-set-state :identifiers identifiers)))
      (error
       (message "BookBrainz identifiers error: %s" (error-message-string err)))))))

(defun bookbrainz--load-relationships-async (entity-type bbid)
  "Fetch relationships for ENTITY-TYPE entity with BBID.
Also triggers name loading for page 1."
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case err
        (let* ((response (bookbrainz--api-request
                          (format "/%s/%s/relationships" entity-type bbid)))
               (relationships (alist-get 'relationships response)))
          (when relationships
            (vui-set-state :relationships relationships)
            (bookbrainz--load-relationship-names relationships 1 8)))
      (error
       (message "BookBrainz relationships error: %s" (error-message-string err)))))))


;;; VUI Component — Search Input

(vui-defcomponent bookbrainz-search-input ()
  :state ((query "")
          (entity-type "author")
          (results nil)
          (total-count 0)
          (loading nil)
          (loading-more nil)
          (error nil))
  :render
    (let ((entity-types '("author" "publisher" "series" "work" "edition-group" "edition"
                          "area" "collection" "editor")))
    (vui-vstack :spacing 1
                (vui-hstack
                 (vui-heading-1 "BookBrainz")
                 (vui-button "Refresh" :on-click (lambda ()
                                                   (bookbrainz--do-search query entity-type))))
                (apply #'vui-hstack :spacing 1
                       (vui-text "Type:" :face 'bold)
                       (mapcar (lambda (et)
                                 (vui-button (if (equal et entity-type)
                                                 (concat "› " et)
                                               et)
                                   :on-click (lambda ()
                                               (vui-set-state :entity-type et))))
                               entity-types))
                (vui-hstack
                 (vui-field :value query
                            :size 60
                            :on-change (lambda (v) (vui-set-state :query v))
                            :placeholder "Search...")
                 (vui-button "Go" :on-click (lambda ()
                                              (bookbrainz--do-search query entity-type))))
                (cond
                 (error   (vui-error error))
                 (results
                  (vui-vstack :spacing 1
                              (vui-component 'bookbrainz-results
                                :results results
                                :total-count total-count
                                :entity-type entity-type
                                :loading-more loading-more
                                :on-load-more (lambda ()
                                                (unless loading-more
                                                  (bookbrainz--load-more query entity-type results))))
                              (when loading-more
                                (vui-muted "Loading more..."))))
                  (loading (vui-muted "Searching..."))
                   (t (vui-muted "Enter a query and press Go"))))))

(defun bookbrainz--do-search (query entity-type)
  (vui-set-state :loading t)
  (vui-set-state :loading-more nil)
  (vui-set-state :results nil)
  (vui-set-state :total-count 0)
  (vui-set-state :error nil)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case err
        (let* ((response (bookbrainz--search entity-type query))
               (results (alist-get 'searchResult response))
               (total (or (alist-get 'totalCount response) (length results))))
          (vui-set-state :loading nil)
          (vui-set-state :results results)
          (vui-set-state :total-count total))
      (error
       (vui-set-state :loading nil)
       (vui-set-state :error (error-message-string err)))))))

(defun bookbrainz--load-more (query entity-type current-results)
  (vui-set-state :loading-more t)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
     (condition-case _
         (let* ((from (length current-results))
                (response (bookbrainz--search entity-type query nil from))
                (items (alist-get 'searchResult response)))
           (vui-set-state :loading-more nil)
           (when items
             (vui-set-state :results (append current-results items))))
       (error
        (vui-set-state :loading-more nil))))))


;;; VUI Component — Search Results

(vui-defcomponent bookbrainz-results (results total-count entity-type on-load-more loading-more)
  :state ((page 0))
  :render
  (let* ((count (length results))
         (page-size bookbrainz-page-size)
         (page page)
         (max-page (if (zerop total-count) 0
                       (/ (1- total-count) page-size)))
         (page-results (seq-drop (seq-take results (* (1+ page) page-size))
                                 (* page page-size))))
    (if (zerop count)
        (vui-muted "No results found")
      (vui-vstack :spacing 1
        (vui-hstack
          (vui-text (if (> total-count count)
                        (format "Found %d/%d result(s)  Page %d/%d"
                                count total-count (1+ page) (1+ max-page))
                      (format "Found %d result(s)  Page %d/%d"
                              count (1+ page) (1+ max-page)))
                    :face 'shadow)
          (when (> page 0)
            (vui-button "[Prev]"
              :on-click (lambda () (vui-set-state :page (1- page)))))
          (when (or loading-more (< page max-page))
            (vui-button (if loading-more "Loading..." "[Next]")
              :on-click (lambda ()
                          (unless loading-more
                            (when (and on-load-more
                                       (>= (* (1+ page) page-size) count))
                              (funcall on-load-more))
                            (vui-set-state :page (1+ page)))))))
        (vui-list page-results
          (lambda (r)
            (let* ((name (bookbrainz--entity-name r))
                   (id (or (alist-get 'bbid r) ""))
                   (detail (bb-format-result (bb-entity-create entity-type nil r))))
              (vui-hstack :spacing 0
                (if (string-empty-p id)
                    (vui-text name :face 'shadow)
                  (vui-button name
                    :on-click (lambda ()
                                (bookbrainz-open-entity entity-type id))))
                (vui-text "  " :face 'shadow)
                (vui-text (substring id 0 8) :face 'shadow)
                (vui-text (format "  %s" detail) :face 'shadow))))
          (lambda (r) (or (alist-get 'bbid r)
                         (bookbrainz--entity-name r))))))))


;;; VUI Component — Entity Detail View

(vui-defcomponent bookbrainz-entity-view (entity-type bbid)
  :state ((entity nil)
          (loading (not (bookbrainz--entity-type-has-api-p entity-type)))
          (error nil)
          (show-raw nil)
          (aliases nil)
          (identifiers nil)
          (relationships nil)
          (relationship-page 1)
          (relationship-names nil))
  :on-mount
  (if (bookbrainz--entity-type-has-api-p entity-type)
      (let ((timer (bookbrainz--load-entity-async
                    entity-type bbid
                    (vui-async-callback (entity)
                      (vui-set-state :entity entity)
                      (vui-set-state :loading nil)
                      (bookbrainz--load-aliases-async entity-type bbid)
                      (bookbrainz--load-identifiers-async entity-type bbid)
                      (bookbrainz--load-relationships-async entity-type bbid))
                    (vui-async-callback (err)
                      (vui-set-state :error (error-message-string err))
                      (vui-set-state :loading nil)))))
        (lambda () (when (timerp timer) (cancel-timer timer))))
    (lambda () nil))
  :render
  (cond
   ((and loading (not (bookbrainz--entity-type-has-api-p entity-type)))
    (vui-vstack :spacing 0
      (vui-heading-1 (bookbrainz--entity-type-label entity-type))
      (vui-muted (format "BBID: %s" bbid))
      (vui-newline)
      (vui-muted "This entity type has no API detail endpoint.")
      (vui-newline)
      (vui-button "Open in Browser"
                  :on-click (lambda ()
                              (browse-url
                               (format "https://bookbrainz.org/%s/%s" entity-type bbid))))
      (vui-button "Close"
                  :on-click (lambda () (quit-window)))))
   (loading
    (vui-vstack :spacing 0
      (vui-heading-1 (format "Loading %s..." bbid))
      (vui-muted "Fetching data from BookBrainz...")))
   (error
    (vui-vstack :spacing 0
      (vui-error (format "Error: %s" error))
      (vui-button "Retry" :on-click
                  (lambda ()
                    (vui-set-state :loading t)
                    (vui-set-state :error nil)
                    (vui-set-state :aliases nil)
                    (vui-set-state :identifiers nil)
                    (vui-set-state :relationships nil)
                    (vui-set-state :show-raw nil)
                    (bookbrainz--load-entity-async
                     entity-type bbid
                     (vui-async-callback (entity)
                       (vui-set-state :entity entity)
                       (vui-set-state :loading nil)
                       (bookbrainz--load-aliases-async entity-type bbid)
                       (bookbrainz--load-identifiers-async entity-type bbid)
                       (bookbrainz--load-relationships-async entity-type bbid))
                     (vui-async-callback (err)
                       (vui-set-state :error (error-message-string err))
                       (vui-set-state :loading nil)))))))
   (entity
    (vui-vstack :spacing 0
      (vui-heading-1 (bookbrainz--entity-name entity))
      (vui-hstack
       (vui-text "BBID: " :face 'shadow)
       (vui-text bbid))
      (vui-hstack
       (vui-text "Type: " :face 'shadow)
       (vui-text (bookbrainz--entity-type-label entity-type)))
      (vui-newline)
      (bb-detail (bb-entity-create entity-type bbid entity))
      (when aliases
        (vui-newline)
        (bookbrainz--aliases-section aliases))
      (when identifiers
        (vui-newline)
        (bookbrainz--identifiers-section identifiers))
      (when relationships
        (vui-newline)
        (bookbrainz--relationships-section
         relationships relationship-page 8 relationship-names
         (lambda (page)
           (vui-set-state :relationship-page page)
           (bookbrainz--load-relationship-names
            relationships page 8))))
      (let ((fields (bookbrainz--entity-data-fields entity '(defaultAlias bbid))))
        (when fields
          (vui-newline)
          (vui-collapsible :title "Entity Data"
            (vui-hstack
              (vui-button (if show-raw "Hide Full" "Show Full")
                          :on-click (lambda ()
                                      (vui-set-state :show-raw (not show-raw)))))
            (apply #'vui-vstack :spacing 0
                   (nconc fields
                          (when show-raw
                            (list (vui-text (let ((json-encoding-pretty-print t))
                                              (json-encode entity))
                                            :face 'shadow))))))))
      (vui-newline)
      (vui-hstack :spacing 0
        (vui-button "Save to Org"
                    :on-click (lambda () (bookbrainz--save-to-org entity-type entity
                                                                   aliases identifiers relationships)))
        (vui-button "Open in Browser"
                    :on-click (lambda ()
                                (browse-url
                                 (format "https://bookbrainz.org/%s/%s" entity-type bbid))))
        (vui-button "Org Props"
                    :on-click (lambda ()
                                (bookbrainz--show-org-properties entity-type entity)))
        (vui-button "Close"
                    :on-click (lambda () (quit-window))))))))


;;; Org integration

(defun bookbrainz--entity-to-org-properties (entity-type entity)
  "Return a string with ENTITY metadata as Org mode :PROPERTIES: drawer."
  (bb-org-props (bb-entity-create entity-type (or (alist-get 'bbid entity) "") entity)))

(defun bookbrainz--show-org-properties (entity-type entity)
  "Display ENTITY metadata as an Org mode PROPERTIES drawer in a temp buffer."
  (let* ((text (bookbrainz--entity-to-org-properties entity-type entity))
         (buf (get-buffer-create "*BB Org Properties*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert text)
      (goto-char (point-min))
      (org-mode))
    (display-buffer buf)
    (message "Org properties shown in buffer *BB Org Properties*")))

(defun bookbrainz--entity-info-to-org (entity)
  "Format ENTITY alist simple fields as Org ** Entity Info section."
  (let (pairs
        (skip '(defaultAlias aliasSet identifierSet relationshipSet
                collections reviews annotation revision dataId)))
    (dolist (pair entity)
      (let ((k (car pair))
            (v (cdr pair)))
        (when (and (symbolp k) (not (memq k skip))
                   (or (stringp v) (numberp v) (booleanp v)))
          (push (format "- %s :: %s" k v) pairs))))
    (when pairs
      (concat "** Entity Info\n"
              (string-join (nreverse pairs) "\n") "\n"))))

(defun bookbrainz--aliases-to-org (aliases)
  "Format ALIASES as Org ** Aliases section."
  (when aliases
    (concat "** Aliases\n"
            (mapconcat
             (lambda (a)
               (let ((name (or (alist-get 'name a) "(unnamed)"))
                     (lang (alist-get 'language a))
                     (sort (alist-get 'sortName a))
                     (primary (alist-get 'primary a)))
                  (concat "- " name
                          (when lang (format " (%s%s)" lang (if primary " *" "")))
                          (when (and sort (not (equal sort name)))
                            (format " [%s]" sort)))))
             aliases "\n") "\n")))

(defun bookbrainz--identifiers-to-org (identifiers)
  "Format IDENTIFIERS as Org ** Identifiers section."
  (when identifiers
    (concat "** Identifiers\n"
            (mapconcat
             (lambda (id)
               (format "- %s :: %s"
                       (or (alist-get 'type id) "unknown")
                       (or (alist-get 'value id) "")))
             identifiers "\n") "\n")))

(defun bookbrainz--relationships-to-org (relationships)
  "Format RELATIONSHIPS as Org ** Relationships section."
  (when relationships
    (concat "** Relationships\n"
            (mapconcat
             (lambda (r)
               (let* ((type (or (alist-get 'relationshipTypeName r) "unknown"))
                      (target (or (alist-get 'targetBbid r) ""))
                      (target-type (or (alist-get 'targetEntityType r) ""))
                      (phrase (or (alist-get 'linkPhrase r) "")))
                 (format "- %s :: %s (%s) %s" type target target-type phrase)))
             relationships "\n") "\n")))

(defun bookbrainz--entity-data-to-org (entity)
  "Format ENTITY raw fields as Org ** Entity Data section."
  (let (pairs
        (skip '(defaultAlias bbid)))
    (dolist (pair entity)
      (let ((k (car pair))
            (v (cdr pair)))
        (when (and (symbolp k) (not (memq k skip))
                   (or (stringp v) (numberp v) (booleanp v)))
          (push (format "- %s :: %s" k v) pairs))))
    (when pairs
      (concat "** Entity Data\n"
              (string-join (nreverse pairs) "\n") "\n"))))

(defun bookbrainz--entity-org-body (entity aliases identifiers relationships)
  "Assemble Org body sections for ENTITY.
Combines info, aliases, identifiers, relationships, and entity data sections."
  (string-join
   (delq nil
     (list
      (bookbrainz--entity-info-to-org entity)
      (bookbrainz--aliases-to-org aliases)
      (bookbrainz--identifiers-to-org identifiers)
      (bookbrainz--relationships-to-org relationships)
      (bookbrainz--entity-data-to-org entity)))
   "\n"))

(defun bookbrainz--save-to-org (entity-type entity &optional aliases identifiers relationships)
  "Save ENTITY as an Org file with a :PROPERTIES: drawer and sections.
ALIASES, IDENTIFIERS, RELATIONSHIPS are optional sub-endpoint data.
File is created at `bookbrainz-org-dir'/TYPE/TIMESTAMP-SLUG.org."
  (let* ((title (bookbrainz--entity-name entity))
         (type-str entity-type)
         (props (bookbrainz--entity-to-org-properties entity-type entity))
         (org-dir (if (bound-and-true-p org-directory)
                       (expand-file-name bookbrainz-org-dir org-directory)
                     (expand-file-name bookbrainz-org-dir "~/")))
         (slug (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase title)))
         (ts (format-time-string "%Y%m%d%H%M%S"))
         (file (expand-file-name (format "%s-%s.org" ts slug)
                                 (expand-file-name type-str org-dir)))
         (body (bookbrainz--entity-org-body entity aliases identifiers relationships))
         (content (if (string-empty-p body)
                      (format "* %s\n%s\n" title props)
                    (format "* %s\n%s\n%s\n" title props body))))
    (make-directory (file-name-directory file) t)
    (with-temp-file file
      (insert content))
    (message "Saved '%s' to %s" title file)))

(defun bookbrainz-open-entity (entity-type bbid)
  (let* ((label (bookbrainz--entity-type-label entity-type))
         (short (substring bbid 0 8))
         (buf (generate-new-buffer-name
               (format "*BB %s %s*" label short))))
    (with-current-buffer (get-buffer-create buf)
      (bookbrainz-mode))
    (vui-mount
     (vui-component 'bookbrainz-entity-view
       :entity-type entity-type
       :bbid bbid)
     buf)))


;;; Major mode

(defvar-keymap bookbrainz-mode-map
  :doc "Keymap for `bookbrainz-mode'.")

(define-derived-mode bookbrainz-mode vui-mode "BookBrainz"
  "Major mode for BookBrainz client.
\\{bookbrainz-mode-map}"
  (setq-local revert-buffer-function #'bookbrainz--revert-buffer))
(set-keymap-parent bookbrainz-mode-map
                   (make-composed-keymap widget-keymap special-mode-map))

(defun bookbrainz--revert-buffer (&optional _ignore-auto _noconfirm)
  (call-interactively #'bookbrainz-search))


;;; Entry point

;;;###autoload
(defun bookbrainz-search ()
  "Open BookBrainz search interface."
  (interactive)
  (let ((buf "*BookBrainz Search*"))
    (when (get-buffer buf)
      (kill-buffer buf))
    (with-current-buffer (get-buffer-create buf)
      (bookbrainz-mode))
    (vui-mount
     (vui-component 'bookbrainz-search-input)
     buf)))

(provide 'bookbrainz)
;;; bookbrainz.el ends here
