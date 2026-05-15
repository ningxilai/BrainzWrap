;;; vino-music.el --- Music collectible preset for vino -*- lexical-binding: t; -*-
;;
;; Music collectible based on MusicBrainz model.
;; Uses original vino patterns: vulpea-create, vulpea-select-from, etc.

(require 'vulpea)
(require 'dash)
(require 's)

;; ============================================================================
;; PART 1: CORE ENTITIES (13 entities)
;; ============================================================================

(defvar vino-music-area-template
  '(:file-name "music/area/${timestamp}-${slug}.org" :tags ("music" "area"))
  "Template for Area entities.")

(defvar vino-music-artist-template
  '(:file-name "music/artist/${timestamp}-${slug}.org" :tags ("music" "artist"))
  "Template for Artist entities.")

(defvar vino-music-event-template
  '(:file-name "music/event/${id}.org" :tags ("music" "event"))
  "Template for Event entities.")

(defvar vino-music-genre-template
  '(:file-name "music/genre/${timestamp}-${slug}.org" :tags ("music" "genre"))
  "Template for Genre entities.")

(defvar vino-music-instrument-template
  '(:file-name "music/instrument/${timestamp}-${slug}.org" :tags ("music" "instrument"))
  "Template for Instrument entities.")

(defvar vino-music-label-template
  '(:file-name "music/label/${timestamp}-${slug}.org" :tags ("music" "label"))
  "Template for Label entities.")

(defvar vino-music-place-template
  '(:file-name "music/place/${timestamp}-${slug}.org" :tags ("music" "place"))
  "Template for Place entities.")

(defvar vino-music-recording-template
  '(:file-name "music/recording/${id}.org" :tags ("music" "recording"))
  "Template for Recording collectibles.")

(defvar vino-music-release-template
  '(:file-name "music/release/${id}.org" :tags ("music" "release"))
  "Template for Release collectibles.")

(defvar vino-music-release-group-template
  '(:file-name "music/release-group/${id}.org" :tags ("music" "release-group"))
  "Template for Release Group collectibles.")

(defvar vino-music-series-template
  '(:file-name "music/series/${timestamp}-${slug}.org" :tags ("music" "series"))
  "Template for Series entities.")

(defvar vino-music-url-template
  '(:file-name "music/url/${timestamp}.org" :tags ("music" "url"))
  "Template for URL entities.")

(defvar vino-music-work-template
  '(:file-name "music/work/${id}.org" :tags ("music" "work"))
  "Template for Work collectibles.")

;; ============================================================================
;; CORE ENTITY: Area
;; ============================================================================

;;;###autoload
(defun vino-music-area-create (&optional title)
  "Create an Area entity."
  (interactive) (vino--create "Area" vino-music-area-template))

;;;###autoload
(defun vino-music-area-select ()
  "Select an Area entity."
  (interactive) (vino--select "Area" 'area #'vino-music-area-create))

;; ============================================================================
;; CORE ENTITY: Artist
;; ============================================================================

;;;###autoload
(defun vino-music-artist-create (&optional title)
  "Create an Artist entity."
  (interactive)
  (let ((title (or title (vino--read-string "Artist: "))))
    (vulpea-create
     title
     (plist-get vino-music-artist-template :file-name)
     :tags (plist-get vino-music-artist-template :tags)
     :meta `(("type" . ,(completing-read "Type: "
                 '("Person" "Group" "Orchestra" "Choir" "Character")))))))

;;;###autoload
(defun vino-music-artist-select ()
  "Select an Artist entity."
  (interactive) (vino--select "Artist" 'artist #'vino-music-artist-create))

;; ============================================================================
;; CORE ENTITY: Event
;; ============================================================================

;;;###autoload
(defun vino-music-event-create ()
  "Create an Event collectible."
  (interactive)
  (let ((title (vino--read-string "Event: ")))
    (vulpea-create
     title
     (plist-get vino-music-event-template :file-name)
     :tags (plist-get vino-music-event-template :tags))))

;;;###autoload
(defun vino-music-event-select ()
  "Select an Event collectible."
  (interactive) (vino--select "Event" 'event))

;; ============================================================================
;; CORE ENTITY: Genre
;; ============================================================================

;;;###autoload
(defun vino-music-genre-create (&optional title)
  "Create a Genre entity."
  (interactive) (vino--create "Genre" vino-music-genre-template))

;;;###autoload
(defun vino-music-genre-select ()
  "Select a Genre entity."
  (interactive) (vino--select "Genre" 'genre #'vino-music-genre-create))

;; ============================================================================
;; CORE ENTITY: Instrument
;; ============================================================================

;;;###autoload
(defun vino-music-instrument-create (&optional title)
  "Create an Instrument entity."
  (interactive) (vino--create "Instrument" vino-music-instrument-template))

;;;###autoload
(defun vino-music-instrument-select ()
  "Select an Instrument entity."
  (interactive) (vino--select "Instrument" 'instrument #'vino-music-instrument-create))

;; ============================================================================
;; CORE ENTITY: Label
;; ============================================================================

;;;###autoload
(defun vino-music-label-create (&optional title)
  "Create a Label entity."
  (interactive)
  (let ((title (or title (vino--read-string "Label: "))))
    (vulpea-create
     title
     (plist-get vino-music-label-template :file-name)
     :tags (plist-get vino-music-label-template :tags)
     :meta `(("type" . ,(completing-read "Type: "
                 '("Production" "Distributor" "Imprint" "Holding")))))))

;;;###autoload
(defun vino-music-label-select ()
  "Select a Label entity."
  (interactive) (vino--select "Label" 'label #'vino-music-label-create))

;; ============================================================================
;; CORE ENTITY: Place
;; ============================================================================

;;;###autoload
(defun vino-music-place-create (&optional title)
  "Create a Place entity."
  (interactive) (vino--create "Place" vino-music-place-template))

;;;###autoload
(defun vino-music-place-select ()
  "Select a Place entity."
  (interactive) (vino--select "Place" 'place #'vino-music-place-create))

;; ============================================================================
;; CORE ENTITY: Recording
;; ============================================================================

;;;###autoload
(defun vino-music-recording-create ()
  "Create a Recording collectible."
  (interactive)
  (let ((title (vino--read-string "Recording: ")))
    (vulpea-create
     title
     (plist-get vino-music-recording-template :file-name)
     :tags (plist-get vino-music-recording-template :tags))))

;;;###autoload
(defun vino-music-recording-select ()
  "Select a Recording collectible."
  (interactive) (vino--select "Recording" 'recording))

;; ============================================================================
;; CORE ENTITY: Release
;; ============================================================================

;;;###autoload
(defun vino-music-release-create ()
  "Create a Release collectible."
  (interactive)
  (let ((title (vino--read-string "Release: ")))
    (vulpea-create
     title
     (plist-get vino-music-release-template :file-name)
     :tags (plist-get vino-music-release-template :tags))))

;;;###autoload
(defun vino-music-release-select ()
  "Select a Release collectible."
  (interactive) (vino--select "Release" 'release))

;; ============================================================================
;; CORE ENTITY: Release Group
;; ============================================================================

;;;###autoload
(defun vino-music-release-group-create ()
  "Create a Release Group collectible."
  (interactive)
  (let ((title (vino--read-string "Release Group: ")))
    (vulpea-create
     title
     (plist-get vino-music-release-group-template :file-name)
     :tags (plist-get vino-music-release-group-template :tags))))

;;;###autoload
(defun vino-music-release-group-select ()
  "Select a Release Group collectible."
  (interactive) (vino--select "Release Group" 'release-group))

;; ============================================================================
;; CORE ENTITY: Series
;; ============================================================================

;;;###autoload
(defun vino-music-series-create (&optional title)
  "Create a Series entity."
  (interactive) (vino--create "Series" vino-music-series-template))

;;;###autoload
(defun vino-music-series-select ()
  "Select a Series entity."
  (interactive) (vino--select "Series" 'series #'vino-music-series-create))

;; ============================================================================
;; CORE ENTITY: URL
;; ============================================================================

;;;###autoload
(defun vino-music-url-create (&optional title)
  "Create a URL entity."
  (interactive)
  (let ((title (or title (vino--read-string "URL: "))))
    (vulpea-create
     title
     (plist-get vino-music-url-template :file-name)
     :tags (plist-get vino-music-url-template :tags))))

;;;###autoload
(defun vino-music-url-select ()
  "Select a URL entity."
  (interactive) (vino--select "URL" 'url))

;; ============================================================================
;; CORE ENTITY: Work
;; ============================================================================

;;;###autoload
(defun vino-music-work-create ()
  "Create a Work collectible."
  (interactive)
  (let ((title (vino--read-string "Work: ")))
    (vulpea-create
     title
     (plist-get vino-music-work-template :file-name)
     :tags (plist-get vino-music-work-template :tags))))

;;;###autoload
(defun vino-music-work-select ()
  "Select a Work collectible."
  (interactive) (vino--select "Work" 'work))

;; ============================================================================
;; PART 2: SECONDARY ENTITIES (3 entities)
;; ============================================================================

(defvar vino-music-medium-template
  '(:file-name "music/medium/${id}.org" :tags ("music" "medium"))
  "Template for Medium secondary entities.")

(defvar vino-music-track-template
  '(:file-name "music/track/${id}.org" :tags ("music" "track"))
  "Template for Track secondary entities.")

(defvar vino-music-artist-credit-template
  '(:file-name "music/artist-credit/${timestamp}.org"
    :tags ("music" "artist" "artist-credit"))
  "Template for Artist Credit secondary entity.")

;; ============================================================================
;; SECONDARY ENTITY: Medium
;; ============================================================================

;;;###autoload
(defun vino-music-medium-create ()
  "Create a Medium secondary entity."
  (interactive)
  (let ((title (vino--read-string "Medium: ")))
    (vulpea-create
     title
     (plist-get vino-music-medium-template :file-name)
     :tags (plist-get vino-music-medium-template :tags))))

;;;###autoload
(defun vino-music-medium-select ()
  "Select a Medium secondary entity."
  (interactive) (vino--select "Medium" 'medium))

;; ============================================================================
;; SECONDARY ENTITY: Track
;; ============================================================================

;;;###autoload
(defun vino-music-track-create ()
  "Create a Track secondary entity."
  (interactive)
  (let ((title (vino--read-string "Track: ")))
    (vulpea-create
     title
     (plist-get vino-music-track-template :file-name)
     :tags (plist-get vino-music-track-template :tags))))

;;;###autoload
(defun vino-music-track-select ()
  "Select a Track secondary entity."
  (interactive) (vino--select "Track" 'track))

;; ============================================================================
;; SECONDARY ENTITY: Artist Credit
;; ============================================================================

;;;###autoload
(defun vino-music-artist-credit-create ()
  "Create an Artist Credit secondary entity."
  (interactive)
  (let* ((artist (vino-music-artist-select))
         (title (vino--read-string "Display name: " (vulpea-note-title artist))))
    (vulpea-create
     title
     (plist-get vino-music-artist-credit-template :file-name)
     :tags (plist-get vino-music-artist-credit-template :tags)
     :meta `(("artist" . ,artist)
             ("joinphrase" . ,(vino--read-string "Join phrase: " " & "))
             ("order" . ,(read-number "Order: " 1))))))

;;;###autoload
(defun vino-music-artist-credit-select ()
  "Select an Artist Credit secondary entity."
  (interactive)
  (vulpea-select-from
   "Artist Credit"
   (vulpea-db-query-by-tags-some '("music" "artist-credit"))
   :expand-aliases t))

;; ============================================================================
;; PART 3: RELATIONSHIPS (*-rels)
;; ============================================================================

(defvar vino-music-rel-prefix "rel:"
  "Prefix for relationship metadata.")

;; Area relationships
(defvar vino-music-area-rels '(area-rels))
(defvar vino-music-artist-rels '(artist-rels))
(defvar vino-music-event-rels '(event-rels))
(defvar vino-music-label-rels '(label-rels))
(defvar vino-music-place-rels '(place-rels))
(defvar vino-music-recording-rels '(recording-rels))
(defvar vino-music-release-rels '(release-rels))
(defvar vino-music-release-group-rels '(release-group-rels))
(defvar vino-music-url-rels '(url-rels))
(defvar vino-music-work-rels '(work-rels))

;; ============================================================================
;; Relationship: work-rels (Work ↔ Artist, Recording, Release)
;; ============================================================================

;;;###autoload
(defun vino-music-work-rels-add (work-note target-note type &optional attribute)
  "Add work-rel: TYPE relationship from WORK-NOTE to TARGET-NOTE.
TYPE can be: artist, recording, release, work."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note work-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list work-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-work-rels-remove (work-note target-note type)
  "Remove work-rel: TYPE from WORK-NOTE to TARGET-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note work-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list work-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-work-rels-get (work-note type)
  "Get targets of work-rel: TYPE from WORK-NOTE.
Returns list of (id . attribute) pairs."
  (vulpea-note-meta-get-list work-note (concat vino-music-rel-prefix type)))

;;;###autoload
(defun vino-music-work-rels-list (work-note)
  "List all work-rels from WORK-NOTE."
  (let (result)
    (maphash
     (lambda (k _v)
       (when (string-prefix-p vino-music-rel-prefix k)
         (push (cons (intern (substring k (length vino-music-rel-prefix))) nil)
               result)))
     (vulpea-note-meta-all work-note))
    result))

;; ============================================================================
;; Relationship: recording-rels (Recording ↔ Artist, Release)
;; ============================================================================

;;;###autoload
(defun vino-music-recording-rels-add (recording-note target-note type &optional attribute)
  "Add recording-rel: TYPE from RECORDING-NOTE to TARGET-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note recording-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list recording-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-recording-rels-remove (recording-note target-note type)
  "Remove recording-rel: TYPE from RECORDING-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note recording-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list recording-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-recording-rels-get (recording-note type)
  "Get targets of recording-rel: TYPE from RECORDING-NOTE."
  (vulpea-note-meta-get-list recording-note (concat vino-music-rel-prefix type)))

;; ============================================================================
;; Relationship: release-rels (Release ↔ Artist, Label, Recording, Release Group, Area)
;; ============================================================================

;;;###autoload
(defun vino-music-release-rels-add (release-note target-note type &optional attribute)
  "Add release-rel: TYPE from RELEASE-NOTE to TARGET-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note release-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list release-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-release-rels-remove (release-note target-note type)
  "Remove release-rel: TYPE from RELEASE-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note release-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list release-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-release-rels-get (release-note type)
  "Get targets of release-rel: TYPE from RELEASE-NOTE."
  (vulpea-note-meta-get-list release-note (concat vino-music-rel-prefix type)))

;; ============================================================================
;; Relationship: release-group-rels
;; ============================================================================

;;;###autoload
(defun vino-music-release-group-rels-add (rg-note target-note type &optional attribute)
  "Add release-group-rel: TYPE from RG-NOTE to TARGET-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note rg-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list rg-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-release-group-rels-remove (rg-note target-note type)
  "Remove release-group-rel: TYPE from RG-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note rg-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id target-note))
                     (vulpea-note-meta-get-list rg-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-release-group-rels-get (rg-note type)
  "Get targets of release-group-rel: TYPE from RG-NOTE."
  (vulpea-note-meta-get-list rg-note (concat vino-music-rel-prefix type)))

;; ============================================================================
;; Relationship: medium-rels (Medium ↔ Track)
;; ============================================================================

;;;###autoload
(defun vino-music-medium-rels-add (medium-note track-note &optional attribute)
  "Add medium-rel:track from MEDIUM-NOTE to TRACK-NOTE."
  (let ((key (concat vino-music-rel-prefix "track")))
    (vulpea-utils-with-note medium-note
                            (vulpea-buffer-meta-set
                             key (cons (cons (vulpea-note-id track-note) attribute)
                                       (vulpea-note-meta-get-list medium-note key)))
                            (save-buffer)
                            (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-medium-rels-remove (medium-note track-note)
  "Remove medium-rel:track from MEDIUM-NOTE."
  (let ((key (concat vino-music-rel-prefix "track")))
    (vulpea-utils-with-note medium-note
      (vulpea-buffer-meta-set
       key (--remove (string= (car it) (vulpea-note-id track-note))
                     (vulpea-note-meta-get-list medium-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-medium-rels-get (medium-note)
  "Get tracks from MEDIUM-NOTE."
  (vulpea-note-meta-get-list medium-note (concat vino-music-rel-prefix "track")))

;; ============================================================================
;; Relationship: artist-rels (Artist ↔ Artist, Label ↔ Label)
;; ============================================================================

;;;###autoload
(defun vino-music-artist-rels-add (artist-note target-note type &optional attribute)
  "Add artist-rel: TYPE from ARTIST-NOTE to TARGET-NOTE (e.g., collaboration)."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note artist-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list artist-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;;;###autoload
(defun vino-music-label-rels-add (label-note target-note type &optional attribute)
  "Add label-rel: TYPE from LABEL-NOTE to TARGET-NOTE."
  (let ((key (concat vino-music-rel-prefix type)))
    (vulpea-utils-with-note label-note
      (vulpea-buffer-meta-set
       key (cons (cons (vulpea-note-id target-note) attribute)
             (vulpea-note-meta-get-list label-note key)))
      (save-buffer)
      (vulpea-db-update-file (buffer-file-name (buffer-base-buffer))))))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(defun vino--read-string (prompt &optional initial-input)
  "Read a string from minibuffer with PROMPT."
  (string-trim (read-string prompt initial-input)))

(defun vino--create (entity template)
  "Create ENTITY with TEMPLATE, prompting for title."
  (let ((title (vino--read-string (concat entity ": "))))
    (vulpea-create
     title
     (plist-get template :file-name)
     :tags (plist-get template :tags))))

(defun vino--select (prompt tag &optional create-fn)
  "Select entity by TAG with PROMPT.
If CREATE-FN is provided and selection is new, prompt to create."
  (let ((note (vulpea-select-from
              prompt
              (vulpea-db-query-by-tags-every (list "music" tag))
              :expand-aliases t)))
    (if (vulpea-note-id note)
        note
      (if create-fn
          (funcall create-fn (vulpea-note-title note))
        note))))

(provide 'vino-music)
;;; vino-music.el ends here
