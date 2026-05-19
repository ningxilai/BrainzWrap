;;; musicbrainz-test.el --- ERT tests for musicbrainz.el  -*- lexical-binding: t; -*-

(require 'ert)


;;; Entity name

(ert-deftest musicbrainz--entity-name-from-name ()
  (should (equal (musicbrainz--entity-name '((name . "Test Name")))
                 "Test Name")))

(ert-deftest musicbrainz--entity-name-from-title ()
  (should (equal (musicbrainz--entity-name '((title . "Test Title")))
                 "Test Title")))

(ert-deftest musicbrainz--entity-name-name-preferred-over-title ()
  (should (equal (musicbrainz--entity-name '((name . "Name")
                                             (title . "Title")))
                 "Name")))

(ert-deftest musicbrainz--entity-name-fallback ()
  (should (equal (musicbrainz--entity-name '((id . "abc")))
                 "(untitled)")))

(ert-deftest musicbrainz--entity-name-nil ()
  (should (equal (musicbrainz--entity-name nil) "(untitled)")))


;;; Entity type label

(ert-deftest musicbrainz--entity-type-label-artist ()
  (should (equal (musicbrainz--entity-type-label "artist") "Artist")))

(ert-deftest musicbrainz--entity-type-label-release ()
  (should (equal (musicbrainz--entity-type-label "release") "Release")))

(ert-deftest musicbrainz--entity-type-label-release-group ()
  (should (equal (musicbrainz--entity-type-label "release-group") "Release Group")))

(ert-deftest musicbrainz--entity-type-label-recording ()
  (should (equal (musicbrainz--entity-type-label "recording") "Recording")))

(ert-deftest musicbrainz--entity-type-label-work ()
  (should (equal (musicbrainz--entity-type-label "work") "Work")))

(ert-deftest musicbrainz--entity-type-label-label ()
  (should (equal (musicbrainz--entity-type-label "label") "Label")))

(ert-deftest musicbrainz--entity-type-label-area ()
  (should (equal (musicbrainz--entity-type-label "area") "Area")))

(ert-deftest musicbrainz--entity-type-label-event ()
  (should (equal (musicbrainz--entity-type-label "event") "Event")))

(ert-deftest musicbrainz--entity-type-label-place ()
  (should (equal (musicbrainz--entity-type-label "place") "Place")))

(ert-deftest musicbrainz--entity-type-label-series ()
  (should (equal (musicbrainz--entity-type-label "series") "Series")))

(ert-deftest musicbrainz--entity-type-label-unknown-fallback ()
  (should (equal (musicbrainz--entity-type-label "custom-type") "Custom-Type")))


;;; Plural / singular entity type conversion

(ert-deftest musicbrainz--plural-entity-type-regular ()
  (should (equal (musicbrainz--plural-entity-type "artist") "artists")))

(ert-deftest musicbrainz--plural-entity-type-series ()
  (should (equal (musicbrainz--plural-entity-type "series") "series")))

(ert-deftest musicbrainz--singular-entity-type-regular ()
  (should (equal (musicbrainz--singular-entity-type "artists") "artist")))

(ert-deftest musicbrainz--singular-entity-type-series ()
  (should (equal (musicbrainz--singular-entity-type "series") "series")))


;;; EIEIO class hierarchy

(ert-deftest mz-entity-create-base ()
  (let ((e (mz-entity-create "artist" "mbid-123" '((name . "Test")))))
    (should (eieio-object-p e))
    (should (equal (mz-type e) "artist"))
    (should (equal (mz-mbid e) "mbid-123"))
    (should (equal (mz-data e) '((name . "Test"))))))

(ert-deftest mz-entity-create-subclass ()
  (let ((e (mz-entity-create "release" "mbid-456" '((title . "Album")))))
    (should (eieio-object-p e))
    (should (equal (class-name (eieio-object-class e)) 'mz-release))))

(ert-deftest mz-entity-create-unknown-fallback ()
  (let ((e (mz-entity-create "custom" "x" nil)))
    (should (eieio-object-p e))
    (should (equal (class-name (eieio-object-class e)) 'mz-entity))))

(ert-deftest mz-name-from-name ()
  (let ((e (mz-entity-create "artist" "x" '((name . "Artist Name")))))
    (should (equal (mz-name e) "Artist Name"))))

(ert-deftest mz-name-from-title ()
  (let ((e (mz-entity-create "release" "x" '((title . "Album")))))
    (should (equal (mz-name e) "Album"))))

(ert-deftest mz-detail-base-fallback ()
  (let ((e (mz-entity-create "custom" "x" nil)))
    (should (equal (mz-detail e) nil))))

(ert-deftest mz-format-result-base-fallback ()
  (let ((e (mz-entity-create "custom" "x" nil)))
    (should (equal (mz-format-result e) ""))))


;;; Format functions

(ert-deftest musicbrainz--format-artist-basic ()
  (should (equal (musicbrainz--format-artist '((name . "Artist1")
                                                (type . "Person")))
                 "Artist1 [Person]")))

(ert-deftest musicbrainz--format-artist-with-country ()
  (should (equal (musicbrainz--format-artist '((name . "Artist1")
                                                (type . "Group")
                                                (country . "US")))
                 "Artist1 [Group] (US)")))

(ert-deftest musicbrainz--format-artist-no-type ()
  (should (equal (musicbrainz--format-artist '((name . "Artist1")))
                 "Artist1")))

(ert-deftest musicbrainz--format-release-basic ()
  (should (equal (musicbrainz--format-release '((title . "Album1")))
                 "Album1")))

(ert-deftest musicbrainz--format-release-with-date-status ()
  (should (equal (musicbrainz--format-release '((title . "Album1")
                                                 (date . "2024")
                                                 (status . "Official")))
                 "Album1 (2024) [Official]")))

(ert-deftest musicbrainz--format-recording-basic ()
  (should (equal (musicbrainz--format-recording '((title . "Song1")))
                 "Song1")))

(ert-deftest musicbrainz--format-recording-with-length ()
  (should (equal (musicbrainz--format-recording '((title . "Song1")
                                                   (length . 245000)))
                 "Song1 (4:05)")))

(ert-deftest musicbrainz--format-release-group-basic ()
  (should (equal (musicbrainz--format-release-group '((title . "RG1")))
                 "RG1")))

(ert-deftest musicbrainz--format-release-group-with-date ()
  (should (equal (musicbrainz--format-release-group '((title . "RG1")
                                                       (first-release-date . "2024")))
                 "RG1 (2024)")))

(ert-deftest musicbrainz--format-work-basic ()
  (should (equal (musicbrainz--format-work '((title . "Work1")))
                 "Work1")))

(ert-deftest musicbrainz--format-work-with-type-language ()
  (should (equal (musicbrainz--format-work '((title . "Work1")
                                              (type . "Symphony")
                                              (language . "en")))
                 "Work1 [Symphony] (en)")))

(ert-deftest musicbrainz--format-label-basic ()
  (should (equal (musicbrainz--format-label '((name . "Label1")))
                 "Label1")))

(ert-deftest musicbrainz--format-label-with-code ()
  (should (equal (musicbrainz--format-label '((name . "Label1")
                                               (type . "Original")
                                               (label-code . 12345)))
                 "Label1 [Original] (LC 12345)")))

(ert-deftest musicbrainz--format-event-basic ()
  (should (equal (musicbrainz--format-event '((name . "Event1")))
                 "Event1")))

(ert-deftest musicbrainz--format-event-with-time ()
  (should (equal (musicbrainz--format-event '((name . "Event1")
                                               (type . "Concert")
                                               (time . "2024-07")))
                 "Event1 [Concert] (2024-07)")))

(ert-deftest musicbrainz--format-place-basic ()
  (should (equal (musicbrainz--format-place '((name . "Venue1")))
                 "Venue1")))

(ert-deftest musicbrainz--format-place-with-address ()
  (should (equal (musicbrainz--format-place '((name . "Venue1")
                                               (type . "Stadium")
                                               (address . "NYC")))
                 "Venue1 [Stadium] (NYC)")))

(ert-deftest musicbrainz--format-series-basic ()
  (should (equal (musicbrainz--format-series '((name . "Series1")))
                 "Series1")))

(ert-deftest musicbrainz--format-series-with-type ()
  (should (equal (musicbrainz--format-series '((name . "Series1")
                                                (type . "Tour")))
                 "Series1 [Tour]")))

(ert-deftest musicbrainz--format-instrument-basic ()
  (should (equal (musicbrainz--format-instrument '((name . "Guitar")))
                 "Guitar")))

(ert-deftest musicbrainz--format-instrument-with-type ()
  (should (equal (musicbrainz--format-instrument '((name . "Guitar")
                                                    (type . "Instrument")))
                 "Guitar [Instrument]")))

(ert-deftest musicbrainz--format-area-basic ()
  (should (equal (musicbrainz--format-area '((name . "Area1")))
                 "Area1")))

(ert-deftest musicbrainz--format-area-with-iso ()
  (should (equal (musicbrainz--format-area '((name . "Area1")
                                              (type . "Country")
                                              (iso-3166-1-codes . ("US" "CA"))))
                 "Area1 [Country] (US)")))


;;; Search & lookup URL construction

(ert-deftest musicbrainz--search-url-params ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url params)
               (list rel-url params))))
    (let ((result (musicbrainz--search "artist" "test query")))
      (should (equal (nth 0 result) "/artist"))
      (should (equal (nth 1 result) '(("query" "test query")
                                        ("limit" "25")
                                        ("offset" "0")))))))


(ert-deftest musicbrainz--search-url-params-custom-size ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url params)
               (list rel-url params))))
    (let ((result (musicbrainz--search "release" "album" 50 10)))
      (should (equal (nth 0 result) "/release"))
      (should (equal (nth 1 result) '(("query" "album")
                                        ("limit" "50")
                                        ("offset" "10")))))))

(ert-deftest musicbrainz--lookup-url ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url &optional params)
               (list rel-url params))))
    (let ((result (musicbrainz--lookup "artist" "mbid-abc")))
      (should (equal (nth 0 result) "/artist/mbid-abc"))
      (should (equal (nth 1 result) nil)))))

(ert-deftest musicbrainz--lookup-url-with-inc ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url &optional params)
               (list rel-url params))))
    (let ((result (musicbrainz--lookup "artist" "mbid-abc" '("recordings"))))
            (should (equal (nth 0 result) "/artist/mbid-abc"))
      (should (equal (nth 1 result) '(("inc" "recordings")))))
))

(ert-deftest musicbrainz--lookup-url-with-complex-inc ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url &optional params)
               (list rel-url params))))
    (let ((result (musicbrainz--lookup "release" "mbid-abc" '("recordings" "artist-credits"))))
            (should (equal (nth 0 result) "/release/mbid-abc"))
      (should (equal (nth 1 result) '(("inc" "recordings artist-credits")))))
))

(ert-deftest musicbrainz--search-url-with-inc ()
  (cl-letf (((symbol-function 'musicbrainz--api-request)
             (lambda (rel-url params)
               (list rel-url params))))
    (let ((result (musicbrainz--search "work" "query" nil nil '("artist-credits"))))
      (should (equal (nth 0 result) "/work"))
      (should (equal (nth 1 result) '(("query" "query")
                                        ("limit" "25")
                                        ("offset" "0")
                                        ("inc" "artist-credits")))))))


;;; mb-let* macro

(ert-deftest mb-let*-basic ()
  (let ((data '((name . "Test") (type . "Person") (extra . "data"))))
    (should (equal (mb-let* data (name type extra)
                     (list name type extra))
                   '("Test" "Person" "data")))))

(ert-deftest mb-when-let*-all-present ()
  (let ((data '((name . "X") (type . "Y"))))
    (should (equal (mb-when-let* data (name type)
                     (list name type))
                   '("X" "Y")))))

(ert-deftest mb-when-let*-missing-key ()
  (let ((data '((name . "X"))))
    (should (equal (mb-when-let* data (name extra)
                     (list name extra))
                   nil))))

(ert-deftest mb-let*-key-omitted-uses-var ()
  (let ((data '((name . "Test"))))
    (should (equal (mb-let* data (name)
                     name)
                   "Test"))))

(ert-deftest mb-let*-nested-data ()
  (let ((data '((artist-credit . ((name . "Artist1"))))))
    (should (equal (mb-let* data
                     ((ac artist-credit))
                     ac)
                   '((name . "Artist1"))))))

(ert-deftest mb-when-let*-nested-data ()
  (let ((data '((artist-credit . ((name . "A1"))))))
    (should (equal (mb-when-let* data
                     ((ac artist-credit))
                     ac)
                   '((name . "A1"))))))

(provide 'musicbrainz-test)
;;; musicbrainz-test.el ends here
