;;; vino-book.el --- Book collectible preset for vino -*- lexical-binding: t; -*-
;;
;; Book collectible based on BookBrainz model.
;; Uses original vino patterns: vulpea-create, vulpea-select-from, etc.

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

(defvar Vino-book-edition-template
  '(:file-name "book/edition/${id}.org" :tags ("book" "edition"))
  "Template for Edition collectibles.")

;; ============================================================================
;; CORE ENTITY: Author
;; ============================================================================

;;;###autoload
(defun vino-book-author-create (&optional title)
  "Create an Author entity (writer, translator, editor, etc.)."
  (interactive)
  (let ((title (or title (vino--read-string "Author: "))))
    (vulpea-create
     title
     (plist-get vino-book-author-template :file-name)
     :tags (plist-get vino-book-author-template :tags))))

;;;###autoload
(defun vino-book-author-select ()
  "Select an Author entity."
  (interactive)
  (let ((note (vulpea-select-from
              "Author"
              (vulpea-db-query-by-tags-every '("book" "author"))
              :expand-aliases t)))
    (if (vulpea-note-id note)
        note
      (if (y-or-n-p (format "Create %s? " (vulpea-note-title note)))
          (vino-book-author-create (vulpea-note-title note))
        note))))

;; ============================================================================
;; CORE ENTITY: Publisher
;; ============================================================================

;;;###autoload
(defun vino-book-publisher-create (&optional title)
  "Create a Publisher entity (company or imprint)."
  (interactive)
  (let ((title (or title (vino--read-string "Publisher: "))))
    (vulpea-create
     title
     (plist-get vino-book-publisher-template :file-name)
     :tags (plist-get vino-book-publisher-template :tags))))

;;;###autoload
(defun vino-book-publisher-select ()
  "Select a Publisher entity."
  (interactive)
  (let ((note (vulpea-select-from
              "Publisher"
              (vulpea-db-query-by-tags-every '("book" "publisher"))
              :expand-aliases t)))
    (if (vulpea-note-id note)
        note
      (if (y-or-n-p (format "Create %s? " (vulpea-note-title note)))
          (vino-book-publisher-create (vulpea-note-title note))
        note))))

;; ============================================================================
;; CORE ENTITY: Series
;; ============================================================================

;;;###autoload
(defun vino-book-series-create (&optional title)
  "Create a Series entity (set of related works/editions)."
  (interactive)
  (let ((title (or title (vino--read-string "Series: "))))
    (vulpea-create
     title
     (plist-get vino-book-series-template :file-name)
     :tags (plist-get vino-book-series-template :tags))))

;;;###autoload
(defun vino-book-series-select ()
  "Select a Series entity."
  (interactive)
  (let ((note (vulpea-select-from
              "Series"
              (vulpea-db-query-by-tags-every '("book" "series"))
              :expand-aliases t)))
    (if (vulpea-note-id note)
        note
      (if (y-or-n-p (format "Create %s? " (vulpea-note-title note)))
          (vino-book-series-create (vulpea-note-title note))
        note))))

;; ============================================================================
;; CORE ENTITY: Work
;; ============================================================================

;;;###autoload
(defun vino-book-work-create ()
  "Create a Work collectible (distinct intellectual creation)."
  (interactive)
  (let ((title (vino--read-string "Work: ")))
    (vulpea-create
     title
     (plist-get vino-book-work-template :file-name)
     :tags (plist-get vino-book-work-template :tags))))

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
  (let ((title (vino--read-string "Edition Group: ")))
    (vulpea-create
     title
     (plist-get vino-book-edition-group-template :file-name)
     :tags (plist-get vino-book-edition-group-template :tags))))

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
  (let ((title (vino--read-string "Edition: ")))
    (vulpea-create
     title
     (plist-get Vino-book-edition-template :file-name)
     :tags (plist-get Vino-book-edition-template :tags))))

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
Example: 'John Doe and Jane Smith' on book cover."
  (interactive)
  (let* ((author (vino-book-author-select))
         (name (vino--read-string "Display name: " (vulpea-note-title author))))
    (vulpea-create
     name
     (plist-get vino-book-author-credit-template :file-name)
     :tags (plist-get vino-book-author-credit-template :tags))))

;;;###autoload
(defun vino-book-author-credit-select ()
  "Select an Author Credit entity."
  (interactive)
  (vulpea-select-from
   "Author Credit"
   (vulpea-db-query-by-tags-some '("book" "author-credit"))
   :expand-aliases t))

;; ============================================================================
;; PART 3: RELATIONSHIPS (*-rels based on BookBrainz)
;; ============================================================================

(defvar vino-book-rel-prefix "rel:")

;; ============================================================================
;; Relationship: author-rels (Author ↔ Work, Edition)
;; ============================================================================

;;;###autoload
(defun vino-book-author-rels-add (author-note target-note type &optional attribute)
  "Add author-rel: TYPE from AUTHOR-NOTE.
TYPE can be: work, edition."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note author-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list author-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-author-rels-remove (author-note target-note type)
  "Remove author-rel: TYPE from AUTHOR-NOTE."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note author-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list author-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-author-rels-get (author-note type)
  "Get targets of author-rel: TYPE from AUTHOR-NOTE."
  (vulpea-note-meta-get-list author-note (concat vino-book-rel-prefix type)))

;; ============================================================================
;; Relationship: work-rels (Work ↔ Work, Author, Language)
;; ============================================================================

;;;###autoload
(defun vino-book-work-rels-add (work-note target-note type &optional attribute)
  "Add work-rel: TYPE from WORK-NOTE.
TYPE can be: author, language, work (translation)."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note work-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list work-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-work-rels-remove (work-note target-note type)
  "Remove work-rel: TYPE from WORK-NOTE."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note work-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list work-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-work-rels-get (work-note type)
  "Get targets of work-rel: TYPE from WORK-NOTE."
  (vulpea-note-meta-get-list work-note (concat vino-book-rel-prefix type)))

;; ============================================================================
;; Relationship: edition-group-rels (Edition Group ↔ Edition)
;; ============================================================================

;;;###autoload
(defun vino-book-edition-group-rels-add (eg-note edition-note)
  "Add EDITION-NOTE to Edition Group EG-NOTE."
  (let ((key (concat vino-book-rel-prefix "edition")))
    (vulpea-utils-with-note eg-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id edition-note) nil)
             (vulpea-note-meta-get-list eg-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-edition-group-rels-remove (eg-note edition-note)
  "Remove EDITION-NOTE from Edition Group EG-NOTE."
  (let ((key (concat vino-book-rel-prefix "edition")))
    (vulpea-utils-with-note eg-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id edition-note))
                     (vulpea-note-meta-get-list eg-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-edition-group-rels-get (eg-note)
  "Get editions from Edition Group EG-NOTE."
  (vulpea-note-meta-get-list eg-note (concat vino-book-rel-prefix "edition")))

;; ============================================================================
;; Relationship: edition-rels (Edition ↔ Work, Publisher, Edition Group, Author Credit)
;; ============================================================================

;;;###autoload
(defun vino-book-edition-rels-add (edition-note target-note type &optional attribute)
  "Add edition-rel: TYPE from EDITION-NOTE.
TYPE can be: work, publisher, edition-group, author-credit."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note edition-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list edition-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-edition-rels-remove (edition-note target-note type)
  "Remove edition-rel: TYPE from EDITION-NOTE."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note edition-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list edition-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-edition-rels-get (edition-note type)
  "Get targets of edition-rel: TYPE from EDITION-NOTE."
  (vulpea-note-meta-get-list edition-note (concat vino-book-rel-prefix type)))

;; ============================================================================
;; Relationship: publisher-rels (Publisher ↔ Edition)
;; ============================================================================

;;;###autoload
(defun vino-book-publisher-rels-add (publisher-note target-note type)
  "Add publisher-rel: TYPE from PUBLISHER-NOTE.
TYPE can be: edition, edition-group."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note publisher-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) nil)
             (vulpea-note-meta-get-list publisher-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-publisher-rels-get (publisher-note type)
  "Get targets of publisher-rel: TYPE from PUBLISHER-NOTE."
  (vulpea-note-meta-get-list publisher-note (concat vino-book-rel-prefix type)))

;; ============================================================================
;; Relationship: series-rels (Series ↔ Work, Edition, Author, Publisher)
;; ============================================================================

;;;###autoload
(defun vino-book-series-rels-add (series-note target-note type)
  "Add series-rel: TYPE from SERIES-NOTE.
TYPE can be: work, edition, author, publisher."
  (let ((key (concat vino-book-rel-prefix type)))
    (vulpea-utils-with-note series-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) nil)
             (vulpea-note-meta-get-list series-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-book-series-rels-get (series-note type)
  "Get targets of series-rel: TYPE from SERIES-NOTE."
  (vulpea-note-meta-get-list series-note (concat vino-book-rel-prefix type)))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(defun vino--read-string (prompt &optional initial-input)
  "Read a string from minibuffer with PROMPT."
  (string-trim (read-string prompt initial-input)))

(provide 'vino-book)
;;; vino-book.el ends here
