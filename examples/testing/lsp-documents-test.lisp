; Test LSP document sync
(import "src/lsp/documents.lisp")

(test-reset)

(test-begin "Document storage - get/set")
(let ((state (make-initial-state)))
  (assert-false (get-document state "file:///test.lisp") "no document initially")
  (let ((state2 (set-document state "file:///test.lisp" "(define x 1)")))
    (assert-eq "(define x 1)" (get-document state2 "file:///test.lisp") "document stored")
    (let ((state3 (set-document state2 "file:///test.lisp" "(define x 2)")))
      (assert-eq "(define x 2)" (get-document state3 "file:///test.lisp") "document updated"))))
(test-end)

(test-begin "Document exists check")
(let ((state (set-document (make-initial-state) "file:///a.lisp" "content")))
  (assert-true (document-exists? state "file:///a.lisp") "document exists")
  (assert-false (document-exists? state "file:///b.lisp") "document does not exist"))
(test-end)

(test-begin "Remove document")
(let ((state (set-document (make-initial-state) "file:///test.lisp" "content")))
  (assert-true (document-exists? state "file:///test.lisp") "document exists before remove")
  (let ((state2 (remove-document state "file:///test.lisp")))
    (assert-false (document-exists? state2 "file:///test.lisp") "document removed")))
(test-end)

(test-begin "didOpen handler")
(let ((state (make-initial-state)))
  (let ((params (list (list "textDocument"
                            (list (list "uri" "file:///new.lisp")
                                  (list "languageId" "lisp")
                                  (list "version" 1)
                                  (list "text" "(+ 1 2)"))))))
    (let ((state2 (handle-did-open state params)))
      (assert-eq "(+ 1 2)" (get-document state2 "file:///new.lisp") "didOpen stores document"))))
(test-end)

(test-begin "didChange handler")
(let ((state (set-document (make-initial-state) "file:///edit.lisp" "old content")))
  (let ((params (list (list "textDocument"
                            (list (list "uri" "file:///edit.lisp")
                                  (list "version" 2)))
                      (list "contentChanges"
                            (list (list (list "text" "new content")))))))
    (let ((state2 (handle-did-change state params)))
      (assert-eq "new content" (get-document state2 "file:///edit.lisp") "didChange updates document"))))
(test-end)

(test-begin "didClose handler")
(let ((state (set-document (make-initial-state) "file:///close.lisp" "content")))
  (let ((params (list (list "textDocument" (list (list "uri" "file:///close.lisp"))))))
    (let ((state2 (handle-did-close state params)))
      (assert-false (document-exists? state2 "file:///close.lisp") "didClose removes document"))))
(test-end)

(test-summary)
