;;; bookbrainz.el --- BookBrainz API client for Emacs  -*- lexical-binding: t; -*-

;; Author: opencode
;; Keywords: query , bookbrainz
;; URL: https://github.com/ningxilai/BrainzWrap
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
(require 'json)
(require 'url)
(require 'vui)
(require 'vui-components)


;;; Custom variables

(defgroup bookbrainz nil
  "BookBrainz API client."
  :group 'external)

(defcustom bookbrainz-api-base "https://api.bookbrainz.org/1"
  "Base URL for the BookBrainz API."
  :type 'string)

(defcustom bookbrainz-user-agent "Emacs-BookBrainz/1.0 (bookbrainz.el)"
  "User-agent string for BookBrainz API requests."
  :type 'string)

(defcustom bookbrainz-page-size 20
  "Number of results per page."
  :type 'integer)

(defcustom bookbrainz-org-dir "bookbrainz"
  "Subdirectory under `org-directory' for saved BookBrainz entities."
  :type 'string)

(defcustom bookbrainz-rate-limit '(1 . 1)
  "Rate limit (requests per second)."
  :type '(cons integer integer))


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


;;; Detail views

(defun bookbrainz--meta (label value)
  (when value
    (vui-hstack
     (vui-text (format " %s:" label) :face 'bold :width 18)
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


;;; Async entity loading

(defun bookbrainz--load-entity-async (entity-type bbid on-success on-error)
  (run-with-idle-timer
   0.1 nil
   (lambda ()
     (condition-case err
         (let* ((entity (bookbrainz--lookup entity-type bbid)))
           (funcall on-success entity))
       (error
        (funcall on-error err))))))


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
          (show-raw nil))
  :on-mount
  (if (bookbrainz--entity-type-has-api-p entity-type)
      (let ((timer (bookbrainz--load-entity-async
                    entity-type bbid
                    (vui-async-callback (entity)
                      (vui-set-state :entity entity)
                      (vui-set-state :loading nil))
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
                    (bookbrainz--load-entity-async
                     entity-type bbid
                     (vui-async-callback (entity)
                       (vui-set-state :entity entity)
                       (vui-set-state :loading nil))
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
      (vui-newline)
      (vui-hstack :spacing 0
        (vui-button "Save to Org"
                    :on-click (lambda () (bookbrainz--save-to-org entity-type entity)))
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
  (bb-org-props (bb-entity-create entity-type (or (alist-get 'bbid entity) "") entity)))

(defun bookbrainz--show-org-properties (entity-type entity)
  (let* ((text (bookbrainz--entity-to-org-properties entity-type entity))
         (buf (get-buffer-create "*BB Org Properties*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert text)
      (goto-char (point-min))
      (org-mode))
    (display-buffer buf)
    (message "Org properties shown in buffer *BB Org Properties*")))

(defun bookbrainz--save-to-org (entity-type entity)
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
         (content (format "* %s\n%s\n" title props)))
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

(defun bookbrainz--revert-buffer (&optional _ignore-auto _noconfirm)
  (call-interactively #'bookbrainz-search))

(defun bookbrainz-browse-url ()
  "Open current entity in web browser."
  (interactive)
  (when-let* ((bbid (get-text-property (point) 'bookbrainz-bbid))
              (etype (get-text-property (point) 'bookbrainz-entity-type)))
    (browse-url (format "https://bookbrainz.org/%s/%s" etype bbid))))

(defun bookbrainz-save-to-org ()
  "Save current entity to an Org file."
  (interactive)
  (user-error "Use the Save to Org button in entity detail view"))


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
