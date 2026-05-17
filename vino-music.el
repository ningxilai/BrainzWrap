;;; vino-music.el --- Music collectible preset for vino -*- lexical-binding: t; -*-
;;
;; Author: opencode
;; Keywords: tools, music, musicbrainz
;; URL: https://github.com/emacs-conf/vino
;; SPDX-License-Identifier: CC0-1.0
;;
;; To the extent possible under law, the author has waived all
;; copyright and related or neighboring rights to this work.
;;
;;; Commentary:
;;
;; Music collectible based on the MusicBrainz data model.
;; Provides 13 core entities (Area, Artist, Event, Genre, Instrument,
;; Label, Place, Recording, Release, Release Group, Series, URL, Work),
;; and 3 secondary entities (Medium, Track, Artist Credit).
;;
;; Package-Requires: ((emacs "29.1") (vino "0.5.0") (vulpea "2.0.0") (dash "2.19.1") (s "1.13.0"))
;;
;;; Code:

(require 'vino)
(require 'vulpea)
(require 'dash)
(require 's)
(eval-when-compile (require 'cl-lib))

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

(defvar vino-music-area-types
  '("Country" "Subdivision" "City" "County" "Municipality" "District" "Island" "Other")
  "MusicBrainz Area types.")

(defvar vino-music-artist-types
  '("Person" "Group" "Orchestra" "Choir" "Character" "Other")
  "MusicBrainz Artist types.")

(defvar vino-music-event-types
  '("Concert" "Festival" "Launch party" "Convention" "Expo"
    "Masterclass" "Workshop" "Competition" "Fan meeting"
    "Award ceremony" "Other")
  "MusicBrainz Event types.")

(defvar vino-music-instrument-types
  '("Wind" "Brass" "Keyboard" "String" "Percussion" "Electronic"
    "Voice" "Other")
  "MusicBrainz Instrument types.")

(defvar vino-music-place-types
  '("Venue" "Studio" "Indoor arena" "Outdoor venue" "Stadium"
    "Religious building" "Other")
  "MusicBrainz Place types.")

(defvar vino-music-release-statuses
  '("Official" "Promotion" "Bootleg" "Pseudo-Release")
  "MusicBrainz Release statuses.")

(defvar vino-music-release-group-types
  '("Album" "Single" "EP" "Broadcast" "Compilation" "Soundtrack"
    "Spokenword" "Interview" "Audiobook" "Live" "Remix" "Other")
  "MusicBrainz Release Group primary types.")

(defvar vino-music-release-group-secondary-types
  '("Compilation" "Soundtrack" "Spokenword" "Interview" "Audiobook"
    "Live" "Remix" "Other")
  "MusicBrainz Release Group secondary types.")

(defvar vino-music-series-types
  '("Tour" "Concert series" "Festival" "Exhibition" "Competition" "Other")
  "MusicBrainz Series types.")

(defvar vino-music-work-types
  '("Aria" "Fugue" "Madrigal" "Opera" "Operetta" "Poem" "Sonata"
    "Song" "Suite" "Symphonic poem" "Symphony" "Other")
  "MusicBrainz Work types.")

(defvar vino-music-medium-formats
  '("CD" "DVD" "Blu-ray" "Cassette" "Vinyl" "Digital Media"
    "SACD" "MiniDisc" "Other")
  "MusicBrainz Medium formats.")

;; ============================================================================
;; CORE ENTITY: Area
;; ============================================================================

;;;###autoload
(defun vino-music-area-create (&optional title)
  "Create an Area entity."
  (interactive)
  (let* ((title (or title (vino--read-string "Area: ")))
         (type (completing-read "Type: " vino-music-area-types nil t))
         (iso (read-string "ISO 3166 code (if country): "))
         (sort-name (read-string "Sort name: " title))
         (note (vulpea-create
                title
                (plist-get vino-music-area-template :file-name)
                :tags (plist-get vino-music-area-template :tags)
                :meta `(("type" . ,type)
                        ("iso" . ,iso)
                        ("sort_name" . ,sort-name)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (or title (vino--read-string "Artist: ")))
         (type (completing-read "Type: " vino-music-artist-types nil t))
         (sort-name (read-string "Sort name: " title))
         (gender (read-string "Gender: "))
         (country (read-string "Country: "))
         (begin (read-string "Begin date: "))
         (end (read-string "End date: "))
         (note (vulpea-create
                title
                (plist-get vino-music-artist-template :file-name)
                :tags (plist-get vino-music-artist-template :tags)
                :meta `(("type" . ,type)
                        ("sort_name" . ,sort-name)
                        ("gender" . ,gender)
                        ("country" . ,country)
                        ("begin" . ,begin)
                        ("end" . ,end)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Event: "))
         (type (completing-read "Type: " vino-music-event-types nil t))
         (time (read-string "Time: "))
         (note (vulpea-create
                title
                (plist-get vino-music-event-template :file-name)
                :tags (plist-get vino-music-event-template :tags)
                :meta `(("type" . ,type)
                        ("time" . ,time)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (interactive) (vino--create "Genre" vino-music-genre-template title))

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
  (interactive)
  (let* ((title (or title (vino--read-string "Instrument: ")))
         (type (completing-read "Type: " vino-music-instrument-types nil t))
         (desc (read-string "Description: "))
         (note (vulpea-create
                title
                (plist-get vino-music-instrument-template :file-name)
                :tags (plist-get vino-music-instrument-template :tags)
                :meta `(("type" . ,type)
                        ("description" . ,desc)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (or title (vino--read-string "Label: ")))
         (type (completing-read "Type: "
                 '("Production" "Distributor" "Imprint" "Holding" "Other") nil t))
         (label-code (read-string "Label code (LC-XXXX): "))
         (country (read-string "Country: "))
         (begin (read-string "Begin date: "))
         (end (read-string "End date: "))
         (note (vulpea-create
                title
                (plist-get vino-music-label-template :file-name)
                :tags (plist-get vino-music-label-template :tags)
                :meta `(("type" . ,type)
                        ("label_code" . ,label-code)
                        ("country" . ,country)
                        ("begin" . ,begin)
                        ("end" . ,end)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (interactive)
  (let* ((title (or title (vino--read-string "Place: ")))
         (type (completing-read "Type: " vino-music-place-types nil t))
         (address (read-string "Address: "))
         (lat (read-string "Latitude: "))
         (lon (read-string "Longitude: "))
         (note (vulpea-create
                title
                (plist-get vino-music-place-template :file-name)
                :tags (plist-get vino-music-place-template :tags)
                :meta `(("type" . ,type)
                        ("address" . ,address)
                        ("lat" . ,lat)
                        ("lon" . ,lon)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Recording: "))
         (length (read-string "Length (seconds): "))
         (video (completing-read "Video: " '("no" "yes") nil t))
         (isrcs (read-string "ISRCs (comma-separated): "))
         (note (vulpea-create
                title
                (plist-get vino-music-recording-template :file-name)
                :tags (plist-get vino-music-recording-template :tags)
                :meta `(("length" . ,length)
                        ("video" . ,video)
                        ("isrcs" . ,isrcs)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Release: "))
         (status (completing-read "Status: " vino-music-release-statuses nil t))
         (date (read-string "Date (YYYY-MM-DD): "))
         (country (read-string "Country: "))
         (barcode (read-string "Barcode: "))
         (packaging (read-string "Packaging: "))
         (labels (read-string "Labels: "))
         (note (vulpea-create
                title
                (plist-get vino-music-release-template :file-name)
                :tags (plist-get vino-music-release-template :tags)
                :meta `(("status" . ,status)
                        ("date" . ,date)
                        ("country" . ,country)
                        ("barcode" . ,barcode)
                        ("packaging" . ,packaging)
                        ("labels" . ,labels)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Release Group: "))
         (type (completing-read "Primary type: " vino-music-release-group-types nil t))
         (secondary (completing-read "Secondary type (empty=none): "
                      vino-music-release-group-secondary-types nil nil))
         (date (read-string "First release date: "))
         (note (vulpea-create
                title
                (plist-get vino-music-release-group-template :file-name)
                :tags (plist-get vino-music-release-group-template :tags)
                :meta `(("type" . ,type)
                        ("secondary_type" . ,secondary)
                        ("first_release_date" . ,date)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (interactive)
  (let* ((title (or title (vino--read-string "Series: ")))
         (type (completing-read "Type: " vino-music-series-types nil t))
         (ordering (read-string "Ordering type: "))
         (note (vulpea-create
                title
                (plist-get vino-music-series-template :file-name)
                :tags (plist-get vino-music-series-template :tags)
                :meta `(("type" . ,type)
                        ("ordering" . ,ordering)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (or title (vino--read-string "URL: ")))
         (note (vulpea-create
                title
                (plist-get vino-music-url-template :file-name)
                :tags (plist-get vino-music-url-template :tags)
                :meta `(("url" . ,title)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Work: "))
         (type (completing-read "Type: " vino-music-work-types nil t))
         (language (read-string "Language (ISO 639): "))
         (iswcs (read-string "ISWCs (comma-separated): "))
         (note (vulpea-create
                title
                (plist-get vino-music-work-template :file-name)
                :tags (plist-get vino-music-work-template :tags)
                :meta `(("type" . ,type)
                        ("language" . ,language)
                        ("iswcs" . ,iswcs)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Medium: "))
         (format (completing-read "Format: " vino-music-medium-formats nil t))
         (position (read-number "Position: " 1))
         (track-count (read-number "Track count: " 1))
         (note (vulpea-create
                title
                (plist-get vino-music-medium-template :file-name)
                :tags (plist-get vino-music-medium-template :tags)
                :meta `(("format" . ,format)
                        ("position" . ,(number-to-string position))
                        ("track_count" . ,(number-to-string track-count))))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
  (let* ((title (vino--read-string "Track: "))
         (position (read-number "Position: " 1))
         (length (read-string "Length (seconds): "))
         (note (vulpea-create
                title
                (plist-get vino-music-track-template :file-name)
                :tags (plist-get vino-music-track-template :tags)
                :meta `(("position" . ,(number-to-string position))
                        ("length" . ,length)))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
         (title (vino--read-string "Display name: " (vulpea-note-title artist)))
         (joinphrase (vino--read-string "Join phrase: " " & "))
         (order (read-number "Order: " 1))
         (note (vulpea-create
                title
                (plist-get vino-music-artist-credit-template :file-name)
                :tags (plist-get vino-music-artist-credit-template :tags)
                :meta `(("artist" . ,artist)
                        ("joinphrase" . ,joinphrase)
                        ("order" . ,(number-to-string order))))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

;;;###autoload
(defun vino-music-artist-credit-select ()
  "Select an Artist Credit secondary entity."
  (interactive)
  (vulpea-select-from
   "Artist Credit"
   (vulpea-db-query-by-tags-some '("music" "artist-credit"))
   :expand-aliases t))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(defun vino--create (entity template &optional title)
  "Create ENTITY with TEMPLATE, prompting for title unless TITLE is given.
Return the created `vulpea-note'."
  (let* ((title (or title (vino--read-string (concat entity ": "))))
         (note (vulpea-create
                title
                (plist-get template :file-name)
                :tags (plist-get template :tags))))
    (vulpea-db-update-file (vulpea-note-path note))
    note))

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
