;;; vino-book.el --- Book collectible preset for vino -*- lexical-binding: t; -*-
;;
;; Author: opencode
;; Keywords: tools, book, bookbrainz
;; URL: https://github.com/emacs-conf/vino
;; SPDX-License-Identifier: CC0-1.0
;;
;; To the extent possible under law, the author has waived all
;; copyright and related or neighboring rights to this work.
;;
;;; Commentary:
;;
;; Book collectible based on the BookBrainz data model.
;; Provides 6 core entities (Author, Publisher, Series, Work,
;; Edition Group, Edition), one secondary entity (Author Credit),
;; and relationship management functions.
;;
;; Package-Requires: ((emacs "29.1") (vino "0.5.0") (vulpea "2.0.0") (dash "2.19.1") (s "1.13.0"))
;;
;;; Code:

(require 'vino)
(require 'vulpea)
(require 'dash)
(require 's)

;; ============================================================================
;; PART 1: CORE ENTITIES (6 entities from BookBrainz)
;; ============================================================================

(defvar vino-book-author-template
  '(:file-name "book/author/${timestamp}-${slug}.org" :tags ("book" "author"))
  "Template for Author entities.")

(defvar vino-book-publisher-template
  '(:file-name "book/publisher/${timestamp}-${slug}.org" :tags ("book" "publisher"))
  "Template for Publisher entities.")

(defvar vino-book-series-template
  '(:file-name "book/series/${timestamp}-${slug}.org" :tags ("book" "series"))
  "Template for Series entities.")

(defvar vino-book-work-template
  '(:file-name "book/work/${id}.org" :tags ("book" "work"))
  "Template for Work collectibles.")

(defvar vino-book-edition-group-template
  '(:file-name "book/edition-group/${id}.org" :tags ("book" "edition-group"))
  "Template for Edition Group collectibles.")

(defvar vino-book-edition-template
  '(:file-name "book/edition/${id}.org" :tags ("book" "edition"))
  "Template for Edition collectibles.")

(defvar vino-book-author-types
  '("Person" "Group" "Other")
  "BookBrainz Author types.")

(defvar vino-book-publisher-types
  '("Publisher" "Imprint" "Other")
  "BookBrainz Publisher types.")

(defvar vino-book-series-types
  '("Work series" "Publisher series" "Edition series"
    "Journal series" "Magazine series" "Other")
  "BookBrainz Series types.")

(defvar vino-book-work-types
  '("Novel" "Short story" "Poem" "Essay" "Play" "Biography"
    "Non-fiction" "Anthology" "Collection" "Periodical" "Other")
  "BookBrainz Work types.")

(defvar vino-book-edition-group-types
  '("Single work" "Collected" "Anthology" "Periodical" "Other")
  "BookBrainz Edition Group types.")

(defvar vino-book-edition-formats
  '("Hardcover" "Paperback" "Mass-market paperback"
    "Library binding" "eBook" "Audiobook (Digital)"
    "Audiobook (Physical)" "CD" "Other")
  "BookBrainz Edition formats.")

(defvar vino-book-edition-statuses
  '("Official" "Draft" "Proof" "Advance Reading Copy" "Other")
  "BookBrainz Edition statuses.")

;; ============================================================================
;; CORE ENTITY: Author
;; ============================================================================

;;;###autoload
(defun vino-book-author-create (&optional title)
  "Create an Author entity (writer, translator, editor, etc.)."
  (interactive)
  (let* ((title (or title (vino--read-string "Author: ")))
         (type (completing-read "Type: " vino-book-author-types nil t))
         (sort-name (read-string "Sort name: " title))
         (gender (read-string "Gender: "))
         (begin (read-string "Birth date: "))
         (end (read-string "Death date: "))
         (note (vulpea-create
                title
                (plist-get vino-book-author-template :file-name)
                :tags (plist-get vino-book-author-template :tags)
                :meta `(("type" . ,type)
                        ("sort_name" . ,sort-name)
                        ("gender" . ,gender)
                        ("begin" . ,begin)
                        ("end" . ,end)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-author-select ()
  "Select an Author entity."
  (interactive)
  (vino--select2 "Author" '("book" "author") #'vino-book-author-create))

;; ============================================================================
;; CORE ENTITY: Publisher
;; ============================================================================

;;;###autoload
(defun vino-book-publisher-create (&optional title)
  "Create a Publisher entity (company or imprint)."
  (interactive)
  (let* ((title (or title (vino--read-string "Publisher: ")))
         (type (completing-read "Type: " vino-book-publisher-types nil t))
         (sort-name (read-string "Sort name: " title))
         (area (read-string "Area: "))
         (begin (read-string "Founded date: "))
         (end (read-string "Dissolved date: "))
         (note (vulpea-create
                title
                (plist-get vino-book-publisher-template :file-name)
                :tags (plist-get vino-book-publisher-template :tags)
                :meta `(("type" . ,type)
                        ("sort_name" . ,sort-name)
                        ("area" . ,area)
                        ("begin" . ,begin)
                        ("end" . ,end)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-publisher-select ()
  "Select a Publisher entity."
  (interactive)
  (vino--select2 "Publisher" '("book" "publisher") #'vino-book-publisher-create))

;; ============================================================================
;; CORE ENTITY: Series
;; ============================================================================

;;;###autoload
(defun vino-book-series-create (&optional title)
  "Create a Series entity (set of related works/editions)."
  (interactive)
  (let* ((title (or title (vino--read-string "Series: ")))
         (type (completing-read "Type: " vino-book-series-types nil t))
         (ordering (read-string "Ordering type: "))
         (note (vulpea-create
                title
                (plist-get vino-book-series-template :file-name)
                :tags (plist-get vino-book-series-template :tags)
                :meta `(("type" . ,type)
                        ("ordering" . ,ordering)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-series-select ()
  "Select a Series entity."
  (interactive)
  (vino--select2 "Series" '("book" "series") #'vino-book-series-create))

;; ============================================================================
;; CORE ENTITY: Work
;; ============================================================================

;;;###autoload
(defun vino-book-work-create ()
  "Create a Work collectible (distinct intellectual creation)."
  (interactive)
  (let* ((title (vino--read-string "Work: "))
         (type (completing-read "Type: " vino-book-work-types nil t))
         (language (read-string "Language (ISO 639): "))
         (note (vulpea-create
                title
                (plist-get vino-book-work-template :file-name)
                :tags (plist-get vino-book-work-template :tags)
                :meta `(("type" . ,type)
                        ("language" . ,language)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-work-select ()
  "Select a Work collectible."
  (interactive)
  (vulpea-select-from
   "Work"
   (vulpea-db-query-by-tags-every '("book" "work"))
   :require-match t
   :expand-aliases t))

;; ============================================================================
;; CORE ENTITY: Edition Group
;; ============================================================================

;;;###autoload
(defun vino-book-edition-group-create ()
  "Create an Edition Group (e.g. paperback + hardcover + ebook)."
  (interactive)
  (let* ((title (vino--read-string "Edition Group: "))
         (type (completing-read "Type: " vino-book-edition-group-types nil t))
         (note (vulpea-create
                title
                (plist-get vino-book-edition-group-template :file-name)
                :tags (plist-get vino-book-edition-group-template :tags)
                :meta `(("type" . ,type)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-edition-group-select ()
  "Select an Edition Group collectible."
  (interactive)
  (vulpea-select-from
   "Edition Group"
   (vulpea-db-query-by-tags-every '("book" "edition-group"))
   :require-match t
   :expand-aliases t))

;; ============================================================================
;; CORE ENTITY: Edition
;; ============================================================================

;;;###autoload
(defun vino-book-edition-create ()
  "Create an Edition collectible (physical or digital version)."
  (interactive)
  (let* ((title (vino--read-string "Edition: "))
         (format (completing-read "Format: " vino-book-edition-formats nil t))
         (isbn (read-string "ISBN: "))
         (pages (read-number "Pages: " 0))
         (date (read-string "Release date: "))
         (status (completing-read "Status: " vino-book-edition-statuses nil t))
         (note (vulpea-create
                title
                (plist-get vino-book-edition-template :file-name)
                :tags (plist-get vino-book-edition-template :tags)
                :meta `(("format" . ,format)
                        ("isbn" . ,isbn)
                        ("pages" . ,(number-to-string pages))
                        ("release_date" . ,date)
                        ("status" . ,status)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-edition-select ()
  "Select an Edition collectible."
  (interactive)
  (vulpea-select-from
   "Edition"
   (vulpea-db-query-by-tags-every '("book" "edition"))
   :require-match t
   :expand-aliases t))

;; ============================================================================
;; PART 2: SECONDARY ENTITIES (Author Credit)
;; ============================================================================

(defvar vino-book-author-credit-template
  '(:file-name "book/author-credit/${timestamp}.org"
    :tags ("book" "author" "author-credit"))
  "Template for Author Credit - how authors are credited on an Edition.")

;; ============================================================================
;; SECONDARY ENTITY: Author Credit
;; ============================================================================

;;;###autoload
(defun vino-book-author-credit-create ()
  "Create an Author Credit (how authors are credited on an Edition).
Example: `John Doe and Jane Smith' on book cover."
  (interactive)
  (let* ((author (vino-book-author-select))
         (name (vino--read-string "Display name: " (vulpea-note-title author)))
         (joinphrase (vino--read-string "Join phrase: " " & "))
         (order (read-number "Order: " 1))
         (note (vulpea-create
                name
                (plist-get vino-book-author-credit-template :file-name)
                :tags (plist-get vino-book-author-credit-template :tags)
                :meta `(("author" . ,(vulpea-note-id author))
                        ("joinphrase" . ,joinphrase)
                        ("order" . ,(number-to-string order))))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-book-author-credit-select ()
  "Select an Author Credit entity."
  (interactive)
  (vulpea-select-from
   "Author Credit"
   (vulpea-db-query-by-tags-some '("book" "author-credit"))
   :expand-aliases t))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(defun vino--select2 (prompt tags create-fn)
  "Select entity by TAGS with PROMPT, creating via CREATE-FN if needed."
  (let ((note (vulpea-select-from
              prompt
              (vulpea-db-query-by-tags-every tags)
              :expand-aliases t)))
    (if (vulpea-note-id note)
        note
      (if (y-or-n-p (format "Create %s? " (vulpea-note-title note)))
          (funcall create-fn (vulpea-note-title note))
        note))))

(provide 'vino-book)
;;; vino-book.el ends here
