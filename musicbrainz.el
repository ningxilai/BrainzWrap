;;; musicbrainz.el --- MusicBrainz client for Emacs  -*- lexical-binding: t; -*-

;; Author: opencode
;; Keywords: query , musicbrainz
;; URL: https://github.com/ningxilai/BrainzWrap
;; SPDX-License-Identifier: CC0-1.0

;; To the extent possible under law, the author has waived all
;; copyright and related or neighboring rights to this work.

;;; Commentary:

;; MusicBrainz API client with VUI frontend.

;; Quick start:
;;   (use-package musicbrainz
;;     :vc (:url "https://github.com/ningxilai/BrainzWrap"))
;;   M-x musicbrainz-search

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'map)
(require 'subr-x)
(require 'json)
(require 'url)

;; vui is required for the macros below.
;; Ensure it's installed before loading this file.
(require 'vui)
(require 'vui-components)

(declare-function vulpea-create "vulpea"
                  (title &optional file-name &key id head meta body
                         context properties tags parent after))


;;; Custom variables

(defgroup musicbrainz nil
  "MusicBrainz API client."
  :group 'external
  :prefix "musicbrainz-")

(defcustom musicbrainz-api-base "https://musicbrainz.org"
  "Base URL for MusicBrainz API v2."
  :type 'string
  :group 'musicbrainz)

(defcustom musicbrainz-user-agent "Emacs-MusicBrainz/1.0 (musicbrainz.el)"
  "User-Agent header for API requests."
  :type 'string
  :group 'musicbrainz)

(defcustom musicbrainz-page-size 25
  "Default number of results per API request (max 100)."
  :type 'integer
  :group 'musicbrainz)

(defcustom musicbrainz-org-dir "musicbrainz"
  "Subdirectory under `org-directory' for saved MusicBrainz entities."
  :type 'string
  :group 'musicbrainz)

(defcustom musicbrainz-rate-limit '(15 . 18)
  "Rate limit as (max-requests . period-seconds).
Default 15 requests per 18 seconds, per MusicBrainz API recommendations."
  :type '(cons integer integer)
  :group 'musicbrainz)


;;; EIEIO entity dispatch + mb-let* macro

(defclass mz-entity ()
  ((type :initarg :type :reader mz-type)
   (mbid :initarg :mbid :reader mz-mbid)
   (data :initarg :data :reader mz-data))
  "Base EIEIO class wrapping a MusicBrainz API alist.")

(defclass mz-artist (mz-entity) ())
(defclass mz-release (mz-entity) ())
(defclass mz-release-group (mz-entity) ())
(defclass mz-recording (mz-entity) ())
(defclass mz-work (mz-entity) ())
(defclass mz-label (mz-entity) ())
(defclass mz-event (mz-entity) ())
(defclass mz-place (mz-entity) ())
(defclass mz-series (mz-entity) ())
(defclass mz-instrument (mz-entity) ())
(defclass mz-area (mz-entity) ())

(defun mz-entity-create (type mbid data)
  "Wrap DATA alist in an EIEIO object for entity TYPE."
  (let ((class (intern-soft (format "mz-%s" type))))
    (if (and class (find-class class))
        (make-instance class :type type :mbid mbid :data data)
      (make-instance 'mz-entity :type type :mbid mbid :data data))))

(cl-defgeneric mz-name (entity)
  "Return display name for ENTITY.")
(cl-defmethod mz-name ((e mz-entity))
  (musicbrainz--entity-name (mz-data e)))

(cl-defgeneric mz-inc (entity)
  "Return inc list for ENTITY's lookup call.")
(cl-defmethod mz-inc ((_e mz-entity)) '("tags"))
(cl-defmethod mz-inc ((_e mz-artist)) '("tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-release)) '("artist-credits" "labels" "recordings" "tags"))
(cl-defmethod mz-inc ((_e mz-release-group)) '("artist-credits" "tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-recording)) '("artist-credits" "releases" "tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-work)) '("tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-label)) '("tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-event)) '("tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-place)) '("tags" "ratings"))
(cl-defmethod mz-inc ((_e mz-area)) '("tags" "ratings"))

(cl-defgeneric mz-detail (entity)
  "Return VUI vnodes for ENTITY's detail view.")
(cl-defmethod mz-detail ((_e mz-entity))
  (vui-muted "Detail view not available for this entity type"))
(cl-defmethod mz-detail ((e mz-artist))
  (musicbrainz--artist-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-release))
  (musicbrainz--release-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-release-group))
  (musicbrainz--release-group-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-recording))
  (musicbrainz--recording-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-work))
  (musicbrainz--work-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-label))
  (musicbrainz--label-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-event))
  (musicbrainz--event-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-place))
  (musicbrainz--place-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-series))
  (musicbrainz--series-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-instrument))
  (musicbrainz--instrument-detail (mz-data e)))
(cl-defmethod mz-detail ((e mz-area))
  (musicbrainz--area-detail (mz-data e)))

(cl-defgeneric mz-format-result (entity)
  "Return a detail string for ENTITY in search results.")
(cl-defmethod mz-format-result ((_e mz-entity)) "")
(cl-defmethod mz-format-result ((e mz-artist))
  (musicbrainz--format-artist (mz-data e)))
(cl-defmethod mz-format-result ((e mz-release))
  (musicbrainz--format-release (mz-data e)))
(cl-defmethod mz-format-result ((e mz-release-group))
  (musicbrainz--format-release-group (mz-data e)))
(cl-defmethod mz-format-result ((e mz-recording))
  (musicbrainz--format-recording (mz-data e)))
(cl-defmethod mz-format-result ((e mz-work))
  (musicbrainz--format-work (mz-data e)))
(cl-defmethod mz-format-result ((e mz-label))
  (musicbrainz--format-label (mz-data e)))
(cl-defmethod mz-format-result ((e mz-event))
  (musicbrainz--format-event (mz-data e)))
(cl-defmethod mz-format-result ((e mz-place))
  (musicbrainz--format-place (mz-data e)))
(cl-defmethod mz-format-result ((e mz-series))
  (musicbrainz--format-series (mz-data e)))
(cl-defmethod mz-format-result ((e mz-instrument))
  (musicbrainz--format-instrument (mz-data e)))
(cl-defmethod mz-format-result ((e mz-area))
  (musicbrainz--format-area (mz-data e)))

(cl-defgeneric mz-org-props (entity &optional json-ld)
  "Return Org :PROPERTIES: drawer string for ENTITY.")
(cl-defmethod mz-org-props ((e mz-entity) &optional json-ld)
  (let* ((data (mz-data e))
         (props (list (format ":ID:          %s" (or (alist-get 'id data) ""))
                      (format ":ENTITY_TYPE: %s" (mz-type e))
                      (format ":NAME:        %s" (mz-name e)))))
    (when-let* ((type (alist-get 'type data)))
      (push (format ":TYPE:        %s" type) props))
    (when-let* ((gender (alist-get 'gender data)))
      (push (format ":GENDER:      %s" gender) props))
    (when-let* ((country (alist-get 'country data)))
      (push (format ":COUNTRY:     %s" country) props))
    (when-let* ((desc (or (alist-get 'description data)
                          (alist-get 'disambiguation data))))
      (push (format ":DESC:        %s" desc) props))
    (when-let* ((rating (alist-get 'rating data)))
      (when-let* ((val (alist-get 'value rating)))
        (push (format ":RATING:      %s/5" (if (numberp val) (format "%.1f" val) val)) props)))
    (let ((life (alist-get 'life-span data)))
      (when life
        (when-let* ((begin (alist-get 'begin life)))
          (push (format ":BORN:        %s" begin) props))
        (when-let* ((end (alist-get 'end life)))
          (push (format ":DIED:        %s" end) props))))
    (let ((tags (alist-get 'tags data)))
      (when tags
        (push (format ":TAGS:        %s"
                      (mapconcat (lambda (tag) (alist-get 'name tag)) tags ", ")) props)))
    (when json-ld
      (when-let* ((url (alist-get '@id json-ld)))
        (push (format ":URL:         %s" url) props)))
    (concat ":PROPERTIES:\n"
            (mapconcat #'identity (nreverse props) "\n")
            "\n:END:")))
(cl-defmethod mz-org-props ((e mz-artist) &optional _json-ld)
  (let* ((data (mz-data e))
         (props (butlast (split-string (cl-call-next-method) "\n" t))))
    (when-let* ((ipis (alist-get 'ipis data)))
      (push (format ":IPIS:        %s" (mapconcat #'identity ipis ", ")) props))
    (when-let* ((isnis (alist-get 'isnis data)))
      (push (format ":ISNIS:       %s" (mapconcat #'identity isnis ", ")) props))
    (concat (mapconcat #'identity (nreverse props) "\n") "\n:END:")))
(cl-defmethod mz-org-props ((e mz-label) &optional _json-ld)
  (let* ((data (mz-data e))
         (props (butlast (split-string (cl-call-next-method) "\n" t))))
    (when-let* ((code (alist-get 'label-code data)))
      (push (format ":LABEL_CODE:  %s" code) props))
    (concat (mapconcat #'identity (nreverse props) "\n") "\n:END:")))

(defmacro mb-let* (data bindings &rest body)
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

(defmacro mb-when-let* (data bindings &rest body)
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


;;; Rate-limited API client (ref: musicbrainz-api TS library)

(defvar musicbrainz--request-log nil
  "List of timestamps for sliding-window rate limiting.")

(defun musicbrainz--wait-if-needed ()
  (let* ((limits musicbrainz-rate-limit)
         (max-req (car limits))
         (period (cdr limits))
         (now (float-time)))
    (setq musicbrainz--request-log
          (seq-filter (lambda (ts) (>= ts (- now period)))
                      musicbrainz--request-log))
    (when (>= (length musicbrainz--request-log) max-req)
      (let* ((oldest (car (last musicbrainz--request-log)))
             (wait (- (+ oldest period) (float-time))))
        (when (> wait 0)
          (sleep-for wait))
        (setq musicbrainz--request-log
              (seq-filter (lambda (ts) (>= ts (- (float-time) period)))
                          musicbrainz--request-log))))
    (push now musicbrainz--request-log)))

(defun musicbrainz--api-request (rel-url &optional params)
  (musicbrainz--wait-if-needed)
  (let* ((url-request-method "GET")
         (url-mime-accept-string "application/json")
         (url-user-agent musicbrainz-user-agent)
         (query `(("fmt" "json") ,@params))
         (url (concat musicbrainz-api-base "/ws/2" rel-url "?"
                      (url-build-query-string query)))
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
             (warn "MusicBrainz API error: %s" err)
             nil)))))))

(defun musicbrainz--plural-entity-type (entity-type)
  "Return the plural form of ENTITY-TYPE for API response keys."
  (pcase entity-type
    ("series" "series")
    (_ (concat entity-type "s"))))

(defun musicbrainz--singular-entity-type (plural-type)
  "Return the singular form of PLURAL-TYPE for browse endpoint paths."
  (pcase plural-type
    ("series" "series")
    (_ (substring plural-type 0 (1- (length plural-type))))))

(defvar musicbrainz--paginated-inc-types
  '("recordings" "releases" "release-groups" "works")
  "Inc types that support full pagination via the browse endpoint.
These are large relationship sets (recordings, releases, etc.)
where the lookup endpoint only returns 25 items but the browse
endpoint supports limit/offset pagination.")

(defun musicbrainz--search (entity-type query &optional limit offset inc)
  (let ((qstr (if (stringp query) query
                (mapconcat (lambda (pair)
                             (format "%s:%s" (car pair) (cdr pair)))
                           query " ")))
        (params nil))
    (push (list "query" qstr) params)
    (push (list "limit" (number-to-string (or limit musicbrainz-page-size))) params)
    (push (list "offset" (number-to-string (or offset 0))) params)
    (when inc
      (push (list "inc" (mapconcat #'identity inc " ")) params))
    (musicbrainz--api-request (format "/%s" entity-type) (nreverse params))))

(defun musicbrainz--lookup (entity-type mbid &optional inc)
  "Lookup ENTITY-TYPE entity with MBID, including related INC types.
For types in `musicbrainz--paginated-inc-types', uses the browse
endpoint with limit/offset pagination (the lookup endpoint returns
at most 25 items per type without count metadata, making it
unusable for reliable pagination)."
  (let* ((params (when inc
                   (list (list "inc" (mapconcat #'identity inc " ")))))
         (response (musicbrainz--api-request
                    (format "/%s/%s" entity-type mbid) params)))
    (when (and response inc)
      (dolist (type inc)
        (when (member type musicbrainz--paginated-inc-types)
          (let* ((browse-type (musicbrainz--singular-entity-type type))
                 (items-key (intern type))
                 (count-key (intern (format "%s-count" browse-type)))
                 (all ())
                 (total nil)
                 (more t))
            (while (and (or (null total) (< (length all) total))
                        more)
              (let* ((page-params (list (list "limit" "100")
                                        (list "offset"
                                              (number-to-string (length all)))
                                        (list entity-type mbid)))
                     (page (musicbrainz--api-request
                            (format "/%s" browse-type) page-params))
                     (page-items (and page (alist-get items-key page))))
                (if (and page-items (listp page-items) (> (length page-items) 0))
                    (progn
                      (setq all (append all page-items))
                      (unless total
                        (setq total (alist-get count-key page)))
                      (when (< (length page-items) 100)
                        (setq more nil)))
                  (setq more nil))))
            (when all
              (setf (alist-get items-key response) all))))))
    response))

;;; JSON-LD field mapping (mirrors R musicbrainz::get_main_parser_lst_ld)

(defvar musicbrainz--json-ld-type-map
  '(("MusicArtist" . "artist")
    ("MusicGroup"  . "artist")
    ("Person"      . "artist")
    ("MusicEvent"  . "event")
    ("MusicLabel"  . "label")
    ("Place"       . "place")
    ("MusicRecording" . "recording")
    ("MusicRelease" . "release")
    ("MusicAlbum"  . "release-group")
    ("AdministrativeArea" . "area")
    ("Instrument"  . "instrument")
    ("Series"      . "series")
    ("Work"        . "work")
    ("Url"         . "url"))
  "Mapping from schema.org @type to MusicBrainz entity type strings.")

(defvar musicbrainz--schema-type-map
  '(("area" . "AdministrativeArea")
    ("artist" . "MusicArtist")
    ("event" . "MusicEvent")
    ("genre" . "Genre")
    ("instrument" . "Instrument")
    ("label" . "MusicLabel")
    ("place" . "Place")
    ("recording" . "MusicRecording")
    ("release" . "MusicRelease")
    ("release-group" . "MusicAlbum")
    ("series" . "Series")
    ("url" . "Url")
    ("work" . "Work"))
  "Reverse mapping from MusicBrainz entity type to schema.org @type.")

(defvar musicbrainz--json-ld-field-mapping
  '((artist (("name" . "name")
             ("sort-name" . "alternateName")
             ("country" . "country")
             ("disambiguation" . "description")
             ("begin" . "birthDate")
             ("end" . "deathDate")
             ("gender" . "gender")))
    (release (("name" . "name")
              ("date" . "datePublished")
              ("country" . "country")
              ("barcode" . "gtin14")
              ("status" . "musicReleaseFormat")
              ("disambiguation" . "description")))
    (release-group (("name" . "name")
                    ("disambiguation" . "description")
                    ("first-release-date" . "datePublished")
                    ("primary-type" . "musicReleaseFormat")))
    (recording (("name" . "name")
                ("length" . "duration")
                ("disambiguation" . "description")
                ("video" . "video")))
    (work (("name" . "name")
           ("language" . "inLanguage")
           ("disambiguation" . "description")))
    (label (("name" . "name")
            ("sort-name" . "alternateName")
            ("label-code" . "identifier")
            ("disambiguation" . "description")
            ("country" . "country")))
    (area (("name" . "name")
           ("sort-name" . "alternateName")
           ("disambiguation" . "description")))
    (place (("name" . "name")
            ("address" . "address")
            ("disambiguation" . "description")))
    (series (("name" . "name")
             ("disambiguation" . "description")))
    (event (("name" . "name")
            ("disambiguation" . "description")))
    (instrument (("name" . "name")
                 ("description" . "description")))
    (url (("description" . "description"))))
  "Mapping from API field names to JSON-LD field names per entity type.
Alist keyed by symbol entity type, each value is a list of (api-field . jsonld-field) cons cells.")

(defvar musicbrainz--json-ld-field-map
  '((artist . ((mbid "@id") (type "@type") (name "name")
               (sort_name "alternateName")
                (gender "@type")
               (birth_date "birthDate") (death_date "deathDate")
                (birth_place "birthPlace" "name")
                (death_place "deathPlace" "name")
                (country "birthPlace" "containedIn" "containedIn" "name")
               (genre "genre") (same_as "sameAs")
               (member_of "memberOf") (album "album")))
    (event . ((mbid "@id") (name "name") (type "@type")
              (start_date "startDate") (end_date "endDate")
              (location "location") (description "description")))
    (label . ((mbid "@id") (type "@type") (name "name")
              (alternate_name "alternateName")
              (address "address") (same_as "sameAs")
              (label_code "identifier")))
    (place . ((mbid "@id") (type "@type") (name "name")
              (address "address") (latitude "latitude")
              (longitude "longitude") (description "description")
               (contained_in "containedInPlace" "name")))
    (recording . ((mbid "@id") (name "name") (duration "duration")
                  (description "description")
                  (by_artist "byArtist") (recording_of "recordingOf")))
    (release . ((mbid "@id") (name "name") (date "datePublished")
                (country "country") (format "musicReleaseFormat")
                (barcode "gtin14") (catalog_number "catalogNumber")
                (credited_to "creditedTo") (description "description")))
    (release-group . ((mbid "@id") (name "name") (type "@type")
                      (description "description") (date "datePublished")
                      (album "album") (by_artist "byArtist")))
    (area . ((mbid "@id") (name "name") (type "@type")
             (iso "addressCountry") (description "description")
             (contained_in "containedIn")))
    (instrument . ((mbid "@id") (type "@type") (name "name")
                   (description "description") (same_as "sameAs")))
    (series . ((mbid "@id") (type "@type") (name "name")
               (description "description")))
    (work . ((mbid "@id") (type "@type") (name "name")
             (language "inLanguage") (description "description")
             (composer "composer") (lyricist "lyricist")
             (genre "genre")))
    (url . ((mbid "@id") (type "@type") (resource "url")
            (description "description")))
    (genre . ((mbid "@id") (name "name") (description "description")
              (disambiguation "disambiguation"))))
  "Field maps from internal field name to JSON-LD key path.
  Each value is a list of (field-name key-path...) where key-path is a
  list of strings for nested access (via `alist-get` chain).")

(defun musicbrainz--json-ld-pluck (data path)
  "Walk DATA along PATH (list of strings) via `alist-get'."
  (if (null path) data
    (let ((val (alist-get (intern (car path)) data)))
      (if (cdr path)
          (musicbrainz--json-ld-pluck val (cdr path))
        val))))

(defun musicbrainz--parse-json-ld (json-ld)
  "Parse JSON-LD alist into a flat field alist using field maps."
  (when json-ld
    (let* ((type-val (alist-get '@type json-ld))
           (type-str (if (listp type-val) (car type-val) type-val))
           (mb-type (alist-get type-str musicbrainz--json-ld-type-map
                               nil nil #'equal))
           (field-map (alist-get mb-type musicbrainz--json-ld-field-map))
           (result `((mb-type . ,mb-type))))
      (dolist (entry field-map result)
        (let* ((field (car entry))
               (path (cdr entry))
               (val (musicbrainz--json-ld-pluck json-ld path)))
          (when val
            (push (cons field val) result)))))))

(defun musicbrainz--build-json-ld-from-entity (entity-type entity mbid)
  "Construct a minimal JSON-LD alist from API ENTITY data.
Uses field mapping to translate API field names to JSON-LD names,
then includes all remaining entity fields with their original keys."
  (let* ((schema-type (alist-get (format "%s" entity-type)
                                 musicbrainz--schema-type-map
                                 nil nil #'equal))
         (result `((@type . ,(or schema-type "Thing"))
                   (@id . ,(format "https://musicbrainz.org/%s/%s" entity-type mbid))))
         (field-map (alist-get (intern (format "%s" entity-type))
                               musicbrainz--json-ld-field-mapping))
         (mapped-api-keys (mapcar (lambda (m) (intern (car m)))
                                  (car field-map))))
    ;; Apply mapped fields first
    (dolist (mapping (car field-map))
      (let* ((api-field (car mapping))
             (ld-field (cdr mapping))
             (value (alist-get (intern api-field) entity)))
        (when value
          (push (cons (intern ld-field) value) result))))
    ;; Then include any remaining entity fields with their original keys
    (dolist (pair entity)
      (let ((key (car pair))
            (val (cdr pair)))
        (unless (memq key mapped-api-keys)
          (push (cons key val) result))))
    result))

(defun musicbrainz--fetch-json-ld (entity-type mbid &optional entity)
  "Fetch JSON-LD for ENTITY-TYPE entity with MBID from the web page URL.
If direct fetch fails, fallback to building from ENTITY data (from API).
Returns parsed JSON alist, or nil on error."
  (let* ((url-request-method "GET")
         (url-request-extra-headers
          '(("Accept" . "application/ld+json")))
         (url (format "https://musicbrainz.org/%s/%s" entity-type mbid)))
    (condition-case nil
        (let ((json-array-type 'list)
              (json-object-type 'alist)
              (json-key-type 'symbol)
              (json-false nil))
          (with-temp-buffer
            (url-insert-file-contents url)
            (set-buffer-multibyte t)
            (decode-coding-region (point-min) (point-max) 'utf-8)
            (goto-char (point-min))
            (json-read)))
      (error
       (if entity
           (musicbrainz--build-json-ld-from-entity entity-type entity mbid)
         nil)))))

(defun musicbrainz--browse (entity-type _query &optional inc)
  (let ((params nil))
    (when inc
      (push (list "inc" (mapconcat #'identity inc " ")) params))
    (musicbrainz--api-request (format "/%s" entity-type) params)))

(defun musicbrainz--browse-page (browse-type entity-type mbid &optional limit offset)
  "Fetch a single page from the browse endpoint for ENTITY-TYPE with MBID.
Returns the parsed response alist."
  (let* ((query-limit (or limit musicbrainz-page-size))
         (params `(("limit" ,(number-to-string query-limit))
                   ("offset" ,(number-to-string (or offset 0)))
                   (,entity-type ,mbid))))
    (musicbrainz--api-request (format "/%s" browse-type) params)))


;;; Entity formatting

(defun musicbrainz--entity-name (entity)
  (or (alist-get 'name entity)
      (alist-get 'title entity)
      "(untitled)"))

(defun musicbrainz--entity-type-label (type)
  (pcase type
    ("artist" "Artist")
    ("release" "Release")
    ("release-group" "Release Group")
    ("recording" "Recording")
    ("work" "Work")
    ("label" "Label")
    ("area" "Area")
    ("event" "Event")
    ("place" "Place")
    ("series" "Series")
    (_ (capitalize (format "%s" type)))))

(defun musicbrainz--format-artist (a)
  (let ((name (alist-get 'name a))
        (type (alist-get 'type a))
        (country (alist-get 'country a)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))
                 (when country (format "(%s)" country))))
     " ")))

(defun musicbrainz--format-release (r)
  (let ((title (alist-get 'title r))
        (date (alist-get 'date r))
        (status (alist-get 'status r))
        (ac (alist-get 'artist-credit r)))
    (format "%s%s%s%s"
            title
            (if date (format " (%s)" date) "")
            (if status (format " [%s]" status) "")
            (if ac
                (format " — %s"
                        (mapconcat
                         (lambda (c)
                           (if (stringp c) c
                             (concat (alist-get 'name c)
                                     (or (alist-get 'joinphrase c) ""))))
                         ac ""))
              ""))))

(defun musicbrainz--format-recording (r)
  (let ((title (alist-get 'title r))
        (len (alist-get 'length r)))
    (format "%s%s" title
            (if len (format " (%d:%02d)"
                            (/ len 60000)
                            (/ (mod len 60000) 1000))
              ""))))

(defun musicbrainz--format-release-group (r)
  (let ((title (alist-get 'title r))
        (date (alist-get 'first-release-date r))
        (primary (alist-get 'primary-type r))
        (ac (alist-get 'artist-credit r)))
    (format "%s%s%s%s" title
            (if date (format " (%s)" date) "")
            (if primary (format " [%s]" primary) "")
            (if ac
                (format " — %s"
                        (mapconcat (lambda (c)
                                     (if (stringp c) c
                                       (concat (alist-get 'name c)
                                               (or (alist-get 'joinphrase c) ""))))
                                   ac ""))
              ""))))

(defun musicbrainz--format-work (w)
  (let ((title (alist-get 'title w))
        (type (alist-get 'type w))
        (language (alist-get 'language w)))
    (string-join
     (delq nil
           (list title
                 (when type (format "[%s]" type))
                 (when language (format "(%s)" language))))
     " ")))

(defun musicbrainz--format-label (l)
  (let ((name (alist-get 'name l))
        (type (alist-get 'type l))
        (code (alist-get 'label-code l)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))
                 (when code (format "(LC %s)" code))))
     " ")))

(defun musicbrainz--format-event (e)
  (let ((name (alist-get 'name e))
        (type (alist-get 'type e))
        (time (alist-get 'time e)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))
                 (when time (format "(%s)" time))))
     " ")))

(defun musicbrainz--format-place (p)
  (let ((name (alist-get 'name p))
        (type (alist-get 'type p))
        (address (alist-get 'address p)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))
                 (when address (format "(%s)" address))))
     " ")))

(defun musicbrainz--format-series (s)
  (let ((name (alist-get 'name s))
        (type (alist-get 'type s)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun musicbrainz--format-instrument (i)
  (let ((name (alist-get 'name i))
        (type (alist-get 'type i)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))))
     " ")))

(defun musicbrainz--format-area (a)
  (let ((name (alist-get 'name a))
        (type (alist-get 'type a))
        (iso (alist-get 'iso-3166-1-codes a)))
    (string-join
     (delq nil
           (list name
                 (when type (format "[%s]" type))
                 (when iso (format "(%s)" (car iso)))))
     " ")))


;;; VUI Component — Search Input

(vui-defcomponent musicbrainz-search-input ()
  :state ((query "")
          (entity-type "artist")
          (results nil)
          (total-count 0)
          (loading nil)
          (loading-more nil)
          (error nil))
  :render
    (let ((entity-types '("artist" "release-group" "release" "recording" "work"
                         "label" "area" "event" "place" "series" "instrument")))
    (vui-vstack :spacing 1
                ;; Header
                (vui-hstack
                 (vui-heading-1 "MusicBrainz")
                 (vui-button "Refresh" :on-click (lambda ()
                                                   (musicbrainz--do-search query entity-type))))
                ;; Entity type selector
                (apply #'vui-hstack :spacing 1
                       (vui-text "Type:" :face 'bold)
                       (mapcar (lambda (et)
                                 (vui-button (if (equal et entity-type)
                                                 (concat "› " et)
                                               et)
                                   :on-click (lambda ()
                                               (vui-set-state :entity-type et))))
                               entity-types))
                ;; Search field
                (vui-hstack
                 (vui-field :value query
                            :size 60
                            :on-change (lambda (v) (vui-set-state :query v))
                            :placeholder "Search...")
                 (vui-button "Go" :on-click (lambda ()
                                              (musicbrainz--do-search query entity-type))))
                ;; Status / results
                (cond
                 (error   (vui-error error))
                 (results
                  (vui-vstack :spacing 1
                              (vui-component 'musicbrainz-results
                                :results results
                                :total-count total-count
                                 :entity-type entity-type
                                :loading-more loading-more
                                 :on-load-more (lambda ()
                                                 (unless loading-more
                                                   (musicbrainz--load-more query entity-type results))))
                               (when loading-more
                                 (vui-muted "Loading more..."))))
                  (loading (vui-muted "Searching..."))
                   (t (vui-muted "Enter a query and press Go"))))))

(defun musicbrainz--do-search (query entity-type)
  (vui-set-state :loading t)
  (vui-set-state :loading-more nil)
  (vui-set-state :results nil)
  (vui-set-state :total-count 0)
  (vui-set-state :error nil)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case err
        (let* ((response (musicbrainz--search entity-type query))
               (key (intern (musicbrainz--plural-entity-type entity-type)))
               (results (alist-get key response))
               (total (or (alist-get 'count response) (length results))))
          (vui-set-state :loading nil)
          (vui-set-state :results results)
          (vui-set-state :total-count total))
      (error
       (vui-set-state :loading nil)
       (vui-set-state :error (error-message-string err)))))))

(defun musicbrainz--load-more (query entity-type current-results)
  (vui-set-state :loading-more t)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
     (condition-case _
         (let* ((offset (length current-results))
                (response (musicbrainz--search entity-type query nil offset))
                (key (intern (musicbrainz--plural-entity-type entity-type)))
                (items (alist-get key response)))
           (vui-set-state :loading-more nil)
           (when items
             (vui-set-state :results (append current-results items))))
       (error
        (vui-set-state :loading-more nil))))))


;;; VUI Component — Search Results

(vui-defcomponent musicbrainz-results (results total-count entity-type on-load-more loading-more)
  :state ((page 0))
  :render
  (let* ((count (length results))
         (page-size 25)
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
        ;; Results list — each row is clickable
        (vui-list page-results
          (lambda (r)
            (let* ((name (musicbrainz--entity-name r))
                   (id (or (alist-get 'id r) ""))
                   (detail (mz-format-result (mz-entity-create entity-type nil r))))
              (vui-hstack :spacing 0
                (vui-button name
                  :on-click (lambda ()
                              (unless (string-empty-p id)
                                (musicbrainz-open-entity entity-type id))))
                (vui-text "  " :face 'shadow)
                (vui-text (substring id 0 8) :face 'shadow)
                (vui-text (format "  %s" detail) :face 'shadow))))
          (lambda (r) (or (alist-get 'id r) (alist-get 'name r))))))))



;;; VUI Component — JSON-LD display

(defun musicbrainz--json-ld-fields (data &optional skip-keys)
  "Return vui children for key-value pairs in alist DATA.
Uses `vui-collapsible' for nested structures."
  (mapcan (pcase-lambda (`(,k . ,v))
            (when (and v (not (memq k (or skip-keys '(mb-type))))
                       (or (not (stringp v)) (not (string-empty-p v))))
               (cond
                ((stringp v)
                 (list (musicbrainz--meta k v)))
                 ((and (listp v) (consp (car v)))
                  (if (and (consp (caar v)) (consp (cdar v)))
                     ;; List of alist items (recordings, tags, releases)
                     (let* ((items v)
                           (names (delq nil
                                       (mapcar (lambda (item)
                                                 (or (alist-get 'name item)
                                                     (alist-get 'title item)
                                                     (alist-get 'id item)
                                                     (and (consp item)
                                                          (format "%s" (car item)))))
                                               items))))
                      (list (musicbrainz--meta k (mapconcat #'identity names ", "))))
                   ;; Nested alist (area, rating, life-span)
                   (let ((name (or (alist-get 'name v) (alist-get 'title v))))
                    (if name
                        (list (musicbrainz--meta k (format "%s" name)))
                      (list
                       (vui-collapsible :title (format "%s" k)
                                        :key k
                         (apply #'vui-vstack :spacing 0
                           (delq nil
                                 (mapcar (pcase-lambda (`(,sk . ,sv))
                                           (when (and sv (not (memq sk skip-keys))
                                                      (or (not (stringp sv))
                                                          (not (string-empty-p sv))))
                                             (musicbrainz--meta (format "%s" sk)
                                                               (if (stringp sv) sv
                                                                 (format "%s" sv)))))
                                          v)))))))))
                ((listp v)
                 (list (musicbrainz--meta k (mapconcat (lambda (x) (format "%s" x)) v ", "))))
                (t
                 (list (musicbrainz--meta k (format "%s" v)))))))
            data))

;;; Async entity loading

(defun musicbrainz--load-entity-async (entity-type mbid on-success on-error)
  "Load ENTITY-TYPE entity with MBID asynchronously.
ON-SUCCESS is called with (entity json-ld) on success.
ON-ERROR is called with (error-condition) on failure.
Returns the timer object.
Callbacks should be created with `vui-async-callback' or `vui-with-async-context'."
  (run-with-idle-timer
   0.1 nil
   (lambda ()
     (condition-case err
            (let* ((inc (mz-inc (mz-entity-create entity-type mbid nil)))
                   (entity (musicbrainz--lookup (format "%s" entity-type) mbid inc))
                (json-ld (musicbrainz--fetch-json-ld entity-type mbid entity)))
           (funcall on-success entity json-ld))
       (error
        (funcall on-error err))))))

;;; VUI Component — Entity Detail

(defun musicbrainz--entity-data-section (label results total-count loading-more
                                        entity-type on-load-more mbid)
  "Render a paginated sub-section inside Entity Data for a large list.
Uses `musicbrainz-results' component with Prev/Next pagination."
  (when (and (listp results) results total-count)
    (list
     (vui-newline)
     (vui-collapsible :title (format "%s (%d)" label total-count)
       (vui-component 'musicbrainz-results
         :results results
         :total-count total-count
         :entity-type entity-type
         :loading-more loading-more
         :on-load-more (lambda ()
                         (unless loading-more
                           (funcall on-load-more mbid results))))))))

(vui-defcomponent musicbrainz-entity-view (entity-type mbid)
                  :state ((entity nil)
                          (json-ld nil)
                          (loading t)
                          (error nil)
                          (show-raw nil)
                          (recording-results nil)
                          (recording-total 0)
                          (recording-loading nil)
                          (work-results nil)
                          (work-total 0)
                          (work-loading nil)
                          (release-results nil)
                          (release-total 0)
                          (release-loading nil))
                  :on-mount
                  (let ((timer (musicbrainz--load-entity-async
                                entity-type mbid
                                (vui-async-callback (entity json-ld)
                                                    (vui-set-state :entity entity)
                                                    (vui-set-state :json-ld json-ld)
                                                     (when (and (equal entity-type "artist") entity)
                                                       (let* ((rec-resp (musicbrainz--browse-page "recording" "artist" mbid))
                                                             (wrk-resp (musicbrainz--browse-page "work" "artist" mbid))
                                                             (rel-resp (musicbrainz--browse-page "release" "artist" mbid)))
                                                        (vui-set-state :recording-results (alist-get 'recordings rec-resp))
                                                        (vui-set-state :recording-total (or (alist-get 'recording-count rec-resp) 0))
                                                        (vui-set-state :work-results (alist-get 'works wrk-resp))
                                                        (vui-set-state :work-total (or (alist-get 'work-count wrk-resp) 0))
                                                        (vui-set-state :release-results (alist-get 'releases rel-resp))
                                                        (vui-set-state :release-total (or (alist-get 'release-count rel-resp) 0))))
                                                    (vui-set-state :loading nil))
                                (vui-async-callback (err)
                                                    (vui-set-state :error (error-message-string err))
                                                    (vui-set-state :loading nil)))))
                    (lambda () (when (timerp timer) (cancel-timer timer))))
                  :render
                  (cond
                   (loading
                    (vui-vstack :spacing 0
                                (vui-heading-1 (format "Loading %s..." mbid))
                                (vui-muted "Fetching data from MusicBrainz...")))
                   (error
                    (vui-vstack :spacing 0
                                (vui-error (format "Error: %s" error))
                                (vui-button "Retry" :on-click
                                            (lambda ()
                                              (vui-set-state :loading t)
                                              (vui-set-state :error nil)
                                              (vui-set-state :show-raw nil)
                                              (vui-set-state :recording-results nil)
                                              (vui-set-state :recording-total 0)
                                              (vui-set-state :recording-loading nil)
                                              (vui-set-state :work-results nil)
                                              (vui-set-state :work-total 0)
                                              (vui-set-state :work-loading nil)
                                              (vui-set-state :release-results nil)
                                              (vui-set-state :release-total 0)
                                              (vui-set-state :release-loading nil)
                                              (musicbrainz--load-entity-async
                                               entity-type mbid
                                               (vui-async-callback (entity json-ld)
                                                                   (vui-set-state :entity entity)
                                                                   (vui-set-state :json-ld json-ld)
(when (and (equal entity-type "artist") entity)
                                                                     (let* ((rec-resp (musicbrainz--browse-page "recording" "artist" mbid))
                                                                            (wrk-resp (musicbrainz--browse-page "work" "artist" mbid))
                                                                            (rel-resp (musicbrainz--browse-page "release" "artist" mbid)))
                                                                       (vui-set-state :recording-results (alist-get 'recordings rec-resp))
                                                                       (vui-set-state :recording-total (or (alist-get 'recording-count rec-resp) 0))
                                                                       (vui-set-state :work-results (alist-get 'works wrk-resp))
                                                                       (vui-set-state :work-total (or (alist-get 'work-count wrk-resp) 0))
                                                                       (vui-set-state :release-results (alist-get 'releases rel-resp))
                                                                       (vui-set-state :release-total (or (alist-get 'release-count rel-resp) 0))))
                                                                   (vui-set-state :loading nil))
                                               (vui-async-callback (err)
                                                                   (vui-set-state :error (error-message-string err))
                                                                   (vui-set-state :loading nil)))))))
                   (entity
                    (vui-vstack :spacing 0
                                (vui-heading-1 (musicbrainz--entity-name entity))
                                ;; Metadata
                                (vui-hstack
                                 (vui-text "MBID: " :face 'shadow)
                                 (vui-text mbid))
                                (vui-hstack
                                 (vui-text "Type: " :face 'shadow)
                                 (vui-text (musicbrainz--entity-type-label entity-type)))
                                (vui-newline)
                                 ;; Type-specific content
                                  (mz-detail (mz-entity-create entity-type mbid entity))
                                ;; Entity Data section (inlined: regular fields + paginated sub-sections)
                                (when json-ld
                                  (vui-newline)
                                  (let ((fields (musicbrainz--json-ld-fields
                                                 json-ld '(@type @id mb-type recordings works releases))))
                                    (when (or fields recording-results work-results release-results show-raw)
                                      (vui-collapsible :title "Entity Data"
                                                       (apply #'vui-vstack :spacing 0
                                                              (delq nil
                                                                    (nconc
                                                                     (list
                                                                      (vui-button (if show-raw "Hide Full" "Show Full")
                                                                                  :on-click (lambda ()
                                                                                              (vui-set-state :show-raw (not show-raw)))))
                                                                     fields
                                                                     (musicbrainz--entity-data-section
                                                                      "Releases" release-results release-total release-loading
                                                                       "release" #'musicbrainz--load-release-page mbid)
                                                                     (musicbrainz--entity-data-section
                                                                      "Recordings" recording-results recording-total recording-loading
                                                                       "recording" #'musicbrainz--load-recording-page mbid)
                                                                     (musicbrainz--entity-data-section
                                                                      "Works" work-results work-total work-loading
                                                                       "work" #'musicbrainz--load-work-page mbid)
                                                                     (when show-raw
                                                                       (list (vui-text (let ((json-encoding-pretty-print t)) (json-encode json-ld)) :face 'shadow))))))))))
                                ;; Actions
                                (vui-newline)
                                 (vui-hstack :spacing 0
                                  (vui-button "Save to Org"
                                              :on-click (lambda () (musicbrainz--save-to-org entity-type entity json-ld)))
                                  (vui-button "Open in Browser"
                                              :on-click (lambda ()
                                                          (browse-url
                                                           (format "https://musicbrainz.org/%s/%s" entity-type mbid))))
                                  (vui-button "Org Props"
                                              :on-click (lambda ()
                                                          (musicbrainz--show-org-properties entity-type entity json-ld)))
                                  (vui-button "Close"
                                              :on-click (lambda () (quit-window))))))))

;;; VUI helpers

(defun musicbrainz--meta (label value)
  (when value
    (vui-hstack
     (vui-text (format " %s:" label) :face 'bold :width 16)
     (vui-text (format "%s" value)))))

(defun musicbrainz--tags-section (entity)
  (let ((tags (alist-get 'tags entity)))
    (when tags
      (vui-collapsible :title "Tags"
        (apply #'vui-vstack :spacing 0
          (mapcar (lambda (tag)
                    (let ((n (alist-get 'name tag)))
                      (musicbrainz--meta n (or (alist-get 'count tag) ""))))
                  tags))))))

;;; Pagination page loaders

(defun musicbrainz--load-recording-page (mbid current-results)
  "Fetch next page of recordings for the artist with MBID.
Appends to `recording-results' state."
  (vui-set-state :recording-loading t)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case _err
        (let* ((offset (length current-results))
               (response (musicbrainz--browse-page "recording" "artist" mbid
                                                   musicbrainz-page-size offset))
               (items (alist-get 'recordings response)))
          (vui-set-state :recording-loading nil)
          (when items
            (vui-set-state :recording-results (append current-results items))))
      (error
       (vui-set-state :recording-loading nil))))))

(defun musicbrainz--load-work-page (mbid current-results)
  "Fetch next page of works for the artist with MBID.
Appends to `work-results' state."
  (vui-set-state :work-loading t)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case _err
        (let* ((offset (length current-results))
               (response (musicbrainz--browse-page "work" "artist" mbid
                                                    musicbrainz-page-size offset))
               (items (alist-get 'works response)))
          (vui-set-state :work-loading nil)
          (when items
            (vui-set-state :work-results (append current-results items))))
      (error
       (vui-set-state :work-loading nil))))))

(defun musicbrainz--load-release-page (mbid current-results)
  "Fetch next page of releases for the artist with MBID.
Appends to `release-results' state."
  (vui-set-state :release-loading t)
  (run-with-idle-timer
   0.1 nil
   (vui-with-async-context
    (condition-case _err
        (let* ((offset (length current-results))
               (response (musicbrainz--browse-page "release" "artist" mbid
                                                    musicbrainz-page-size offset))
               (items (alist-get 'releases response)))
          (vui-set-state :release-loading nil)
          (when items
            (vui-set-state :release-results (append current-results items))))
      (error
       (vui-set-state :release-loading nil))))))

;;; Entity detail views

(defun musicbrainz--artist-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Country" (alist-get 'country entity))
    (musicbrainz--meta "Sort Name" (alist-get 'sort-name entity))
    (musicbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))
    (let ((life (alist-get 'life-span entity)))
      (when life
        (vui-collapsible :title "Life Span"
          (musicbrainz--meta "Born" (alist-get 'begin life))
          (musicbrainz--meta "Died" (alist-get 'end life)))))
    (let ((tags (alist-get 'tags entity)))
      (when tags
        (vui-collapsible :title "Tags"
          (apply #'vui-vstack :spacing 0
            (mapcar (lambda (tag)
                      (let ((n (alist-get 'name tag)))
                        (musicbrainz--meta n (or (alist-get 'count tag) ""))))
                    tags)))))))

(defun musicbrainz--release-detail (entity)
  (vui-vstack :spacing 0
              (musicbrainz--meta "Status" (alist-get 'status entity))
              (musicbrainz--meta "Date" (alist-get 'date entity))
              (musicbrainz--meta "Country" (alist-get 'country entity))
              (musicbrainz--meta "Barcode" (alist-get 'barcode entity))
              (let ((ac (alist-get 'artist-credit entity)))
                (when ac
                  (musicbrainz--meta "Artists"
                                     (mapconcat (lambda (c)
                                                  (if (stringp c) c
                                                    (concat (alist-get 'name c)
                                                            (or (alist-get 'joinphrase c) ""))))
                                                ac ""))))
              (let ((labels (alist-get 'label-info entity)))
                (when labels
                  (vui-collapsible :title (format "Labels (%d)" (length labels))
                    (apply #'vui-vstack :spacing 0
                      (mapcar (lambda (l)
                                (when-let* ((label (alist-get 'label l)))
                                  (vui-hstack
                                    (vui-text (format "- %s" (alist-get 'name label)))
                                    (when-let* ((cat (alist-get 'catalog-number l)))
                                      (vui-text (format " (%s)" cat) :face 'shadow)))))
                              labels)))))))

(defun musicbrainz--recording-detail (entity)
  (vui-vstack :spacing 0
              (musicbrainz--meta "Length"
                                 (let ((len (alist-get 'length entity)))
                                   (when len
                                     (format "%d:%02d" (/ len 60000) (/ (mod len 60000) 1000)))))
              (musicbrainz--meta "Video" (alist-get 'video entity))))

(defun musicbrainz--work-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Language" (alist-get 'language entity))))

(defun musicbrainz--release-group-detail (entity)
  (mb-let* entity ((primary-type primary-type) (secondary secondary-types) (ac artist-credit)
                   (date first-release-date) (desc disambiguation))
    (vui-vstack :spacing 0
      (musicbrainz--meta "Primary Type" primary-type)
      (when secondary
        (musicbrainz--meta "Secondary Types"
                           (mapconcat #'identity secondary ", ")))
      (when ac
        (let ((fmt (mapconcat (lambda (c)
                                (if (stringp c) c
                                  (concat (alist-get 'name c)
                                          (or (alist-get 'joinphrase c) ""))))
                              ac "")))
          (musicbrainz--meta "Artists" fmt)))
      (musicbrainz--meta "First Release Date" date)
      (musicbrainz--meta "Disambiguation" desc)
      (musicbrainz--tags-section entity))))

(defun musicbrainz--label-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Sort Name" (alist-get 'sort-name entity))
    (musicbrainz--meta "Label Code" (alist-get 'label-code entity))
    (musicbrainz--meta "Country" (alist-get 'country entity))
    (let ((life (alist-get 'life-span entity)))
      (when life
        (vui-collapsible :title "Life Span"
          (musicbrainz--meta "Begin" (alist-get 'begin life))
          (musicbrainz--meta "End" (alist-get 'end life)))))
    (musicbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))
    (musicbrainz--tags-section entity)))

(defun musicbrainz--event-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Time" (alist-get 'time entity))
    (musicbrainz--meta "Cancelled" (alist-get 'cancelled entity))
    (let ((setlist (alist-get 'setlist entity))
          (life (alist-get 'life-span entity)))
      (when (and setlist (not (string= setlist "")))
        (musicbrainz--meta "Setlist" setlist))
      (when life
        (vui-collapsible :title "Date"
          (musicbrainz--meta "Begin" (alist-get 'begin life))
          (musicbrainz--meta "End" (alist-get 'end life)))))
    (musicbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))
    (musicbrainz--tags-section entity)))

(defun musicbrainz--place-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Address" (alist-get 'address entity))
    (let ((coords (alist-get 'coordinates entity)))
      (when coords
        (vui-collapsible :title "Coordinates"
          (musicbrainz--meta "Latitude" (alist-get 'latitude coords))
          (musicbrainz--meta "Longitude" (alist-get 'longitude coords)))))
    (let ((life (alist-get 'life-span entity)))
      (when life
        (vui-collapsible :title "Life Span"
          (musicbrainz--meta "Begin" (alist-get 'begin life))
          (musicbrainz--meta "End" (alist-get 'end life)))))
    (musicbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))
    (musicbrainz--tags-section entity)))

(defun musicbrainz--series-detail (entity)
  (mb-let* entity (type (desc disambiguation))
    (vui-vstack :spacing 0
      (musicbrainz--meta "Type" type)
      (musicbrainz--meta "Disambiguation" desc)
      (musicbrainz--tags-section entity))))

(defun musicbrainz--instrument-detail (entity)
  (mb-let* entity (type (desc description))
    (vui-vstack :spacing 0
      (musicbrainz--meta "Type" type)
      (musicbrainz--meta "Description" desc)
      (musicbrainz--tags-section entity))))

(defun musicbrainz--area-detail (entity)
  (vui-vstack :spacing 0
    (musicbrainz--meta "Type" (alist-get 'type entity))
    (musicbrainz--meta "Sort Name" (alist-get 'sort-name entity))
    (let ((iso (alist-get 'iso-3166-1-codes entity)))
      (when iso
        (musicbrainz--meta "ISO Code" (string-join iso ", "))))
    (let ((life (alist-get 'life-span entity)))
      (when life
        (vui-collapsible :title "Life Span"
          (musicbrainz--meta "Begin" (alist-get 'begin life))
          (musicbrainz--meta "End" (alist-get 'end life)))))
    (musicbrainz--meta "Disambiguation" (alist-get 'disambiguation entity))
    (musicbrainz--tags-section entity)))

;;; Org integration

(defun musicbrainz--entity-to-org-properties (entity-type entity &optional json-ld)
  "Return a string with ENTITY metadata as Org mode :PROPERTIES: drawer."
  (mz-org-props (mz-entity-create entity-type (or (alist-get 'id entity) "") entity) json-ld))

(defun musicbrainz--show-org-properties (entity-type entity &optional json-ld)
  "Display ENTITY metadata as an Org mode PROPERTIES drawer in a temp buffer."
  (let* ((text (musicbrainz--entity-to-org-properties entity-type entity json-ld))
         (buf (get-buffer-create "*MB Org Properties*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert text)
      (goto-char (point-min))
      (org-mode))
    (display-buffer buf)
    (message "Org properties shown in buffer *MB Org Properties*")))

(defun musicbrainz--save-to-org (entity-type entity &optional json-ld)
  "Save ENTITY as an Org file with a :PROPERTIES: drawer.
File is created at `musicbrainz-org-dir'/TYPE/TIMESTAMP-SLUG.org."
  (let* ((title (musicbrainz--entity-name entity))
         (type-str (format "%s" entity-type))
         (props (musicbrainz--entity-to-org-properties entity-type entity json-ld))
         (org-dir (if (bound-and-true-p org-directory)
                      (expand-file-name musicbrainz-org-dir org-directory)
                    (expand-file-name musicbrainz-org-dir "~/")))
         (dir (expand-file-name (format "%s" type-str) org-dir))
         (slug (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase title)))
         (ts (format-time-string "%Y%m%d%H%M%S"))
         (file (expand-file-name (format "%s-%s.org" ts slug) dir))
         (content (format "* %s\n%s\n" title props)))
    (make-directory dir t)
    (with-temp-file file
      (insert content))
    (message "Saved '%s' to %s" title file)))

(defun musicbrainz-open-entity (entity-type mbid)
  "Open ENTITY-TYPE entity with MBID in a new buffer."
  (let* ((label (musicbrainz--entity-type-label entity-type))
         (short (substring mbid 0 8))
         (buf (generate-new-buffer-name
               (format "*MB %s %s*" label short))))
    (with-current-buffer (get-buffer-create buf)
      (musicbrainz-mode))
    (vui-mount
     (vui-component 'musicbrainz-entity-view
       :entity-type entity-type
       :mbid mbid)
     buf)))


;;; Major mode

(defvar-keymap musicbrainz-mode-map
  :doc "Keymap for `musicbrainz-mode'.")

(define-derived-mode musicbrainz-mode vui-mode "MusicBrainz"
  "Major mode for MusicBrainz client.
\\{musicbrainz-mode-map}"
  (setq-local revert-buffer-function #'musicbrainz--revert-buffer))

(defun musicbrainz--revert-buffer (&optional _ignore-auto _noconfirm)
  (call-interactively #'musicbrainz-search))

(defun musicbrainz-browse-url ()
  "Open current entity in web browser."
  (interactive)
  (when-let* ((mbid (get-text-property (point) 'musicbrainz-mbid))
             (etype (get-text-property (point) 'musicbrainz-entity-type)))
    (browse-url (format "https://musicbrainz.org/%s/%s" etype mbid))))

(defun musicbrainz-save-to-org ()
  "Save current entity to an Org file."
  (interactive)
  (user-error "Use the Save to Org button in entity detail view"))


;;; Entry point

;;;###autoload
(defun musicbrainz-search ()
  "Open MusicBrainz search interface."
  (interactive)
  (let ((buf "*MusicBrainz Search*"))
    (when (get-buffer buf)
      (kill-buffer buf))
    (with-current-buffer (get-buffer-create buf)
      (musicbrainz-mode))
    (vui-mount
     (vui-component 'musicbrainz-search-input)
     buf)))

(provide 'musicbrainz)
;;; musicbrainz.el ends here
