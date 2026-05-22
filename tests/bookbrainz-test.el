;;; bookbrainz-test.el --- ERT tests for bookbrainz.el  -*- lexical-binding: t; -*-

(require 'ert)


;;; Entity name

(ert-deftest bookbrainz--entity-name-from-name-key ()
  (should (equal (bookbrainz--entity-name '((name . "Test Name")))
                 "Test Name")))

(ert-deftest bookbrainz--entity-name-from-defaultAlias ()
  (should (equal (bookbrainz--entity-name '((defaultAlias (name . "Alias Name"))))
                 "Alias Name")))

(ert-deftest bookbrainz--entity-name-name-preferred-over-alias ()
  (should (equal (bookbrainz--entity-name '((name . "Direct Name")
                                            (defaultAlias (name . "Alias Name"))))
                 "Direct Name")))

(ert-deftest bookbrainz--entity-name-fallback ()
  (should (equal (bookbrainz--entity-name '((bbid . "abc")))
                 "(untitled)")))

(ert-deftest bookbrainz--entity-name-empty-alist ()
  (should (equal (bookbrainz--entity-name nil)
                 "(untitled)")))


;;; Entity type label

(ert-deftest bookbrainz--entity-type-label-author ()
  (should (equal (bookbrainz--entity-type-label "author") "Author")))

(ert-deftest bookbrainz--entity-type-label-publisher ()
  (should (equal (bookbrainz--entity-type-label "publisher") "Publisher")))

(ert-deftest bookbrainz--entity-type-label-series ()
  (should (equal (bookbrainz--entity-type-label "series") "Book Series")))

(ert-deftest bookbrainz--entity-type-label-work ()
  (should (equal (bookbrainz--entity-type-label "work") "Book Work")))

(ert-deftest bookbrainz--entity-type-label-edition-group ()
  (should (equal (bookbrainz--entity-type-label "edition-group") "Edition Group")))

(ert-deftest bookbrainz--entity-type-label-edition ()
  (should (equal (bookbrainz--entity-type-label "edition") "Edition")))

(ert-deftest bookbrainz--entity-type-label-area ()
  (should (equal (bookbrainz--entity-type-label "area") "Area")))

(ert-deftest bookbrainz--entity-type-label-collection ()
  (should (equal (bookbrainz--entity-type-label "collection") "Collection")))

(ert-deftest bookbrainz--entity-type-label-editor ()
  (should (equal (bookbrainz--entity-type-label "editor") "Editor")))

(ert-deftest bookbrainz--entity-type-label-unknown-fallback ()
  (should (equal (bookbrainz--entity-type-label "custom-type") "Custom-type")))


;;; Entity type API check

(ert-deftest bookbrainz--entity-type-has-api-p-author ()
  (should (bookbrainz--entity-type-has-api-p "author")))

(ert-deftest bookbrainz--entity-type-has-api-p-edition ()
  (should (bookbrainz--entity-type-has-api-p "edition")))

(ert-deftest bookbrainz--entity-type-has-api-p-work ()
  (should (bookbrainz--entity-type-has-api-p "work")))

(ert-deftest bookbrainz--entity-type-has-api-p-area-false ()
  (should-not (bookbrainz--entity-type-has-api-p "area")))

(ert-deftest bookbrainz--entity-type-has-api-p-collection-false ()
  (should-not (bookbrainz--entity-type-has-api-p "collection")))

(ert-deftest bookbrainz--entity-type-has-api-p-editor-false ()
  (should-not (bookbrainz--entity-type-has-api-p "editor")))


;;; EIEIO class hierarchy

(ert-deftest bb-entity-create-base ()
  (let ((e (bb-entity-create "author" "bbid-123" '((name . "Test")))))
    (should (eieio-object-p e))
    (should (equal (bb-type e) "author"))
    (should (equal (bb-bbid e) "bbid-123"))
    (should (equal (bb-data e) '((name . "Test"))))))

(ert-deftest bb-entity-create-subclass ()
  (let ((e (bb-entity-create "work" "bbid-456" '((workType . "Novel")))))
    (should (eieio-object-p e))
    (should (equal (class-name (eieio-object-class e)) 'bb-work))))

(ert-deftest bb-entity-create-unknown-fallback ()
  (let ((e (bb-entity-create "unknown" "x" nil)))
    (should (eieio-object-p e))
    (should (equal (class-name (eieio-object-class e)) 'bb-entity))))

(ert-deftest bb-name ()
  (let ((e (bb-entity-create "author" "x" '((name . "Author Name")))))
    (should (equal (bb-name e) "Author Name"))))

(ert-deftest bb-name-from-alias ()
  (let ((e (bb-entity-create "author" "x" '((defaultAlias (name . "Alias"))))))
    (should (equal (bb-name e) "Alias"))))

(ert-deftest bb-detail-base-fallback ()
  (let ((e (bb-entity-create "unknown" "x" nil)))
    (should (equal (bb-detail e) nil))))

(ert-deftest bb-format-result-base-fallback ()
  (let ((e (bb-entity-create "unknown" "x" nil)))
    (should (equal (bb-format-result e) ""))))


;;; Org properties

(ert-deftest bb-org-props-basic ()
  (let ((e (bb-entity-create "author" "bbid-1" '((bbid . "bbid-1") (name . "Test")))))
    (let ((props (bb-org-props e)))
      (should (string-match ":ID:          bbid-1" props))
      (should (string-match ":ENTITY_TYPE: author" props))
      (should (string-match ":NAME:        Test" props))
      (should (string-match ":PROPERTIES:" props))
      (should (string-match ":END:" props)))))

(ert-deftest bb-org-props-with-disambiguation ()
  (let ((e (bb-entity-create "work" "bbid-2" '((name . "W") (disambiguation . "Note")))))
    (should (string-match ":DESC:        Note" (bb-org-props e)))))

(ert-deftest bb-org-props-no-disambiguation ()
  (let ((e (bb-entity-create "author" "bbid-3" '((name . "X")))))
    (should-not (string-match ":DESC:" (bb-org-props e)))))


;;; Date formatting

(ert-deftest bookbrainz--format-date-extended-iso ()
  (should (equal (bookbrainz--format-date "+001954-07-29") "1954-07-29")))

(ert-deftest bookbrainz--format-date-year-only ()
  (should (equal (bookbrainz--format-date "+001974") "1974")))

(ert-deftest bookbrainz--format-date-no-prefix ()
  (should (equal (bookbrainz--format-date "1954-07-29") "1954-07-29")))

(ert-deftest bookbrainz--format-date-nil ()
  (should (equal (bookbrainz--format-date nil) nil)))

(ert-deftest bookbrainz--format-date-empty-string ()
  (should (equal (bookbrainz--format-date "") "")))


;;; Format helpers

(ert-deftest bookbrainz--format-publishers-basic ()
  (should (equal (bookbrainz--format-publishers
                  '(((name . "Pub1") (sortName . "Pub1"))
                    ((name . "Pub2") (sortName . "Pub2"))))
                 "Pub1, Pub2")))

(ert-deftest bookbrainz--format-publishers-nil ()
  (should (equal (bookbrainz--format-publishers nil) nil)))

(ert-deftest bookbrainz--format-publishers-empty ()
  (should (equal (bookbrainz--format-publishers '()) nil)))

(ert-deftest bookbrainz--format-author-credits-basic ()
  (should (equal (bookbrainz--format-author-credits
                  '((names ((name . "Auth1") (joinPhrase . ""))
                           ((name . "Auth2")))))
                 "Auth1, Auth2")))

(ert-deftest bookbrainz--format-author-credits-nil ()
  (should (equal (bookbrainz--format-author-credits nil) nil)))

(ert-deftest bookbrainz--format-author-credits-no-names ()
  (should (equal (bookbrainz--format-author-credits '((bbid . "x"))) nil)))


;;; Search & lookup URL construction

(ert-deftest bookbrainz--search-url-params ()
  (let ((url-request-method "GET")
        (url-mime-accept-string "application/json")
        (url-user-agent "test"))
    (cl-letf (((symbol-function 'bookbrainz--api-request)
               (lambda (rel-url params)
                 (list rel-url params))))
      (let ((result (bookbrainz--search "author" "test query" 10 0)))
        (should (equal (nth 0 result) "/search"))
        (should (equal (nth 1 result) '(("q" "test query")
                                          ("type" "author")
                                          ("size" "10")
                                          ("from" "0"))))))))

(ert-deftest bookbrainz--search-url-params-defaults ()
  (cl-letf (((symbol-function 'bookbrainz--api-request)
             (lambda (rel-url &optional params)
               (list rel-url params))))
    (let ((result (bookbrainz--search "work" "hobbit")))
      (should (equal (nth 0 result) "/search"))
      (should (equal (nth 1 result) '(("q" "hobbit")
                                        ("type" "work")
                                        ("size" "20")
                                        ("from" "0")))))))

(ert-deftest bookbrainz--lookup-url ()
  (cl-letf (((symbol-function 'bookbrainz--api-request)
             (lambda (rel-url &optional params)
               (list rel-url params))))
    (let ((result (bookbrainz--lookup "author" "bbid-abc")))
      (should (equal (nth 0 result) "/author/bbid-abc"))
      (should (equal (nth 1 result) nil)))))


;;; Format functions

(ert-deftest bookbrainz--format-author-basic ()
  (should (equal (bookbrainz--format-author '((name . "John")
                                              (defaultAlias (name . "John"))
                                              (authorType . "Person")))
                 "John [Person]")))

(ert-deftest bookbrainz--format-author-no-type ()
  (should (equal (bookbrainz--format-author '((name . "John")))
                 "John")))

(ert-deftest bookbrainz--format-publisher-basic ()
  (should (equal (bookbrainz--format-publisher '((defaultAlias (name . "Pub"))
                                                 (publisherType . "Publisher")))
                 "Pub [Publisher]")))

(ert-deftest bookbrainz--format-work-no-type ()
  (should (equal (bookbrainz--format-work '((defaultAlias (name . "Work1"))))
                 "Work1")))

(ert-deftest bookbrainz--format-edition-with-date ()
  (should (equal (bookbrainz--format-edition '((defaultAlias (name . "Ed"))
                                               (releaseEventDate . "+001954")))
                 "Ed (1954)")))

(ert-deftest bookbrainz--format-edition-with-format ()
  (should (equal (bookbrainz--format-edition '((defaultAlias (name . "Ed"))
                                               (editionFormat . "Paperback")))
                 "Ed [Paperback]")))

(ert-deftest bookbrainz--ended-label-nil ()
  (should (equal (bookbrainz--ended-label nil) nil)))

(ert-deftest bookbrainz--ended-label-t ()
  ;; VUI component function — just check it doesn't error
  (bookbrainz--ended-label t))


;;; Search result handling

(ert-deftest bookbrainz--entity-name-from-search-author ()
  (should (equal (bookbrainz--entity-name
                  '((defaultAlias (name . "J. R. R. Tolkien") (sortName . "Tolkien, J. R. R."))
                    (entityType . "Author")))
                 "J. R. R. Tolkien")))

(ert-deftest bb-format-result-author ()
  (let ((e (bb-entity-create "author" nil
              '((name . "Test Author") (authorType . "Person")))))
    (should (equal (bb-format-result e) "Test Author [Person]"))))

(ert-deftest bb-format-result-work ()
  (let ((e (bb-entity-create "work" nil
              '((defaultAlias (name . "Test Work")) (workType . "Novel")))))
    (should (equal (bb-format-result e) "Test Work [Novel]"))))

(ert-deftest bb-format-result-edition ()
  (let ((e (bb-entity-create "edition" nil
              '((defaultAlias (name . "Test Ed"))
                (releaseEventDate . "+001954")
                (editionFormat . "Paperback")))))
    (should (equal (bb-format-result e) "Test Ed (1954) [Paperback]"))))


;;; Org integration

(ert-deftest bookbrainz--entity-info-to-org-basic ()
  (let ((entity '((name . "Test Entity")
                   (type . "Author")
                   (bbid . "bbid-abc")
                   (defaultAlias (name . "Alias"))
                   (disambiguation . "Note"))))
    (should (string-match "\\*\\* Entity Info" (bookbrainz--entity-info-to-org entity)))
    (should (string-match "- name :: Test Entity" (bookbrainz--entity-info-to-org entity)))
    (should (string-match "- disambiguation :: Note" (bookbrainz--entity-info-to-org entity)))
    (should-not (string-match "defaultAlias" (bookbrainz--entity-info-to-org entity)))))

(ert-deftest bookbrainz--entity-info-to-org-nil ()
  (should (equal (bookbrainz--entity-info-to-org nil) nil)))

(ert-deftest bookbrainz--entity-info-to-org-skips-collections ()
  (let ((entity '((name . "X") (collections . ((bbid . "c1"))))))
    (should-not (string-match "collections" (bookbrainz--entity-info-to-org entity)))))

(ert-deftest bookbrainz--aliases-to-org-basic ()
  (let ((aliases '(((name . "Main Name") (language . "en") (primary . t)))))
    (let ((result (bookbrainz--aliases-to-org aliases)))
      (should (string-match "\\*\\* Aliases" result))
      (should (string-match "- Main Name (en \\*)" result)))))

(ert-deftest bookbrainz--aliases-to-org-with-sort ()
  (let ((aliases '(((name . "John") (sortName . "Doe")))))
    (let ((result (bookbrainz--aliases-to-org aliases)))
      (should (string-match "- John \\[Doe\\]" result)))))

(ert-deftest bookbrainz--aliases-to-org-nil ()
  (should (equal (bookbrainz--aliases-to-org nil) nil)))

(ert-deftest bookbrainz--aliases-to-org-empty ()
  (should (equal (bookbrainz--aliases-to-org '()) nil)))

(ert-deftest bookbrainz--aliases-to-org-no-language ()
  (let ((aliases '(((name . "Plain")))))
    (should (string-match "- Plain" (bookbrainz--aliases-to-org aliases)))
    (should-not (string-match "(en)" (bookbrainz--aliases-to-org aliases)))))

(ert-deftest bookbrainz--aliases-to-org-no-sort-when-equal ()
  (let ((aliases '(((name . "Same") (sortName . "Same")))))
    (let ((result (bookbrainz--aliases-to-org aliases)))
      (should (string-match "- Same" result))
      (should-not (string-match "\\[.*Same" result)))))

(ert-deftest bookbrainz--identifiers-to-org-basic ()
  (let ((ids '(((type . "ISBN") (value . "123-456")))))
    (should (string-match "\\*\\* Identifiers" (bookbrainz--identifiers-to-org ids)))
    (should (string-match "- ISBN :: 123-456" (bookbrainz--identifiers-to-org ids)))))

(ert-deftest bookbrainz--identifiers-to-org-nil ()
  (should (equal (bookbrainz--identifiers-to-org nil) nil)))

(ert-deftest bookbrainz--identifiers-to-org-unknown-type ()
  (let ((ids '(((value . "v1")))))
    (should (string-match "unknown" (bookbrainz--identifiers-to-org ids)))))

(ert-deftest bookbrainz--relationships-to-org-basic ()
  (let ((rels '(((relationshipTypeName . "Author") (targetBbid . "bbid-x")
                 (targetEntityType . "work") (linkPhrase . "wrote")))))
    (should (string-match "\\*\\* Relationships" (bookbrainz--relationships-to-org rels)))
    (should (string-match "Author :: bbid-x (work) wrote"
                          (bookbrainz--relationships-to-org rels)))))

(ert-deftest bookbrainz--relationships-to-org-nil ()
  (should (equal (bookbrainz--relationships-to-org nil) nil)))

(ert-deftest bookbrainz--entity-data-to-org-basic ()
  (let ((entity '((name . "X") (type . "Author") (bbid . "bbid-1") (extra . "val"))))
    (should (string-match "\\*\\* Entity Data" (bookbrainz--entity-data-to-org entity)))
    (should (string-match "extra :: val" (bookbrainz--entity-data-to-org entity)))
    (should-not (string-match "bbid" (bookbrainz--entity-data-to-org entity)))))

(ert-deftest bookbrainz--entity-data-to-org-nil ()
  (should (equal (bookbrainz--entity-data-to-org nil) nil)))

(ert-deftest bookbrainz--entity-org-body-assembles-sections ()
  (let* ((entity '((name . "Test")))
         (aliases '(((name . "A1"))))
         (ids '(((type . "ISBN") (value . "123"))))
         (rels '(((relationshipTypeName . "Rel1") (targetBbid . "x")
                  (targetEntityType . "work") (linkPhrase . "")))))
    (let ((body (bookbrainz--entity-org-body entity aliases ids rels)))
      (should (string-match "\\*\\* Entity Info" body))
      (should (string-match "\\*\\* Aliases" body))
      (should (string-match "\\*\\* Identifiers" body))
      (should (string-match "\\*\\* Relationships" body))
      (should (string-match "\\*\\* Entity Data" body)))))

(ert-deftest bookbrainz--entity-org-body-nils-omitted ()
  (should (equal (bookbrainz--entity-org-body nil nil nil nil) "")))
