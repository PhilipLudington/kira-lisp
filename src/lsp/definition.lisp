; LSP Go To Definition
; Task 3.7: textDocument/definition
;
; Resolves symbol under cursor and returns location in current document.
; Supports definitions from:
; - define
; - defmacro
; - simple let binding lists

(import "src/lsp/protocol.lisp")
(import "src/lsp/documents.lisp")
(import "src/json.lisp")

(provide
  handle-definition-request
  find-definition-location)

; ============================================================================
; Helpers
; ============================================================================

(define (nth n lst)
  (if (null? lst)
      #f
      (if (= n 0)
          (car lst)
          (nth (- n 1) (cdr lst)))))

(define (safe-json-get obj key)
  (if (json-object? obj)
      (json-get obj key)
      'null))

(define (trim-left s)
  (if (equal? s "")
      s
      (let ((c (string-ref s 0)))
        (if (or (equal? c " ") (equal? c "\t"))
            (trim-left (substring s 1 (string-length s)))
            s))))

(define (starts-with? s prefix)
  (let ((plen (string-length prefix)))
    (if (< (string-length s) plen)
        #f
        (equal? (substring s 0 plen) prefix))))

(define (contains-substring-at s needle idx)
  (let ((nlen (string-length needle)))
    (if (> (+ idx nlen) (string-length s))
        #f
        (equal? (substring s idx (+ idx nlen)) needle))))

(define (contains-substring-from s needle idx slen nlen)
  (if (> (+ idx nlen) slen)
      #f
      (if (contains-substring-at s needle idx)
          #t
          (contains-substring-from s needle (+ idx 1) slen nlen))))

(define (contains-substring s needle)
  (let ((slen (string-length s)))
    (let ((nlen (string-length needle)))
      (if (> nlen slen)
          #f
          (contains-substring-from s needle 0 slen nlen)))))

(define (leading-space-count line)
  (- (string-length line) (string-length (trim-left line))))

(define extra-symbol-chars
  (list "+" "-" "*" "/" "<" ">" "=" "!" "?" "_" "." ":" "%" "&" "^" "~" "@" "$"))

(define (contains-char? c chars)
  (if (null? chars)
      #f
      (if (equal? c (car chars))
          #t
          (contains-char? c (cdr chars)))))

(define (symbol-char? c)
  (or (and (>= (char->integer c) 48) (<= (char->integer c) 57))
      (or (and (>= (char->integer c) 65) (<= (char->integer c) 90))
          (or (and (>= (char->integer c) 97) (<= (char->integer c) 122))
              (contains-char? c extra-symbol-chars)))))

(define (symbol-start-index line idx)
  (if (<= idx 0)
      0
      (if (symbol-char? (string-ref line (- idx 1)))
          (symbol-start-index line (- idx 1))
          idx)))

(define (symbol-end-index line idx len)
  (if (>= idx len)
      len
      (if (symbol-char? (string-ref line idx))
          (symbol-end-index line (+ idx 1) len)
          idx)))

(define (symbol-at-position text line-num char-num)
  (let ((lines (string-split text "\n")))
    (let ((line (nth line-num lines)))
      (if (not line)
          #f
          (let ((len (string-length line)))
            (if (= len 0)
                #f
                (let ((idx (if (>= char-num len) (- len 1) char-num)))
                  (if (< idx 0)
                      #f
                      (let ((probe
                              (if (symbol-char? (string-ref line idx))
                                  idx
                                  (if (and (> idx 0) (symbol-char? (string-ref line (- idx 1))))
                                      (- idx 1)
                                      -1))))
                        (if (< probe 0)
                            #f
                            (let ((start (symbol-start-index line probe)))
                              (let ((end (symbol-end-index line probe len)))
                                (substring line start end)))))))))))))

(define (parse-name-at line col)
  (if (>= col (string-length line))
      #f
      (let ((start col))
        (let ((end (symbol-end-index line start (string-length line))))
          (if (<= end start)
              #f
              (list (substring line start end) start))))))

(define (with-indent info indent)
  (if (not info)
      #f
      (list (car info) (+ indent (car (cdr info))))))

(define (extract-define-info line)
  (let ((trimmed (trim-left line)))
    (let ((indent (leading-space-count line)))
      (if (starts-with? trimmed "(define ")
          (if (and (> (string-length trimmed) 8)
                   (equal? (string-ref trimmed 8) "("))
              ; (define (name ...) ...)
              (with-indent (parse-name-at trimmed 9) indent)
              ; (define name ...)
              (with-indent (parse-name-at trimmed 8) indent))
          #f))))

(define (extract-defmacro-info line)
  (let ((trimmed (trim-left line)))
    (let ((indent (leading-space-count line)))
      (if (starts-with? trimmed "(defmacro ")
          (if (and (> (string-length trimmed) 10)
                   (equal? (string-ref trimmed 10) "("))
              ; (defmacro (name ...) ...)
              (with-indent (parse-name-at trimmed 11) indent)
              ; (defmacro name ...)
              (with-indent (parse-name-at trimmed 10) indent))
          #f))))

(define (skip-spaces line idx len)
  (if (>= idx len)
      idx
      (let ((c (string-ref line idx)))
        (if (or (equal? c " ") (equal? c "\t"))
            (skip-spaces line (+ idx 1) len)
            idx))))

(define (find-matching-paren line idx depth len)
  (if (>= idx len)
      len
      (let ((c (string-ref line idx)))
        (if (equal? c "(")
            (find-matching-paren line (+ idx 1) (+ depth 1) len)
            (if (equal? c ")")
                (if (= depth 1)
                    idx
                    (find-matching-paren line (+ idx 1) (- depth 1) len))
                (find-matching-paren line (+ idx 1) depth len))))))

(define (collect-let-bindings line idx len acc)
  (let ((i (skip-spaces line idx len)))
    (if (>= i len)
        acc
        (if (and (< (+ i 1) len)
                 (equal? (string-ref line i) ")")
                 (equal? (string-ref line (+ i 1)) ")"))
            acc
            (if (equal? (string-ref line i) "(")
                (let ((name-col (+ i 1)))
                  (let ((info (parse-name-at line name-col)))
                    (let ((close (find-matching-paren line i 0 len)))
                      (if (>= close len)
                          (if info
                              (cons info acc)
                              acc)
                          (collect-let-bindings
                            line
                            (+ close 1)
                            len
                            (if info
                                (cons info acc)
                                acc))))))
                (collect-let-bindings line (+ i 1) len acc))))))

(define (extract-let-binding-infos line)
  (let ((trimmed (trim-left line)))
    (let ((indent (leading-space-count line)))
      (if (starts-with? trimmed "(let ")
          (let ((prefix-len (string-length "(let ")))
            (let ((base (+ indent prefix-len)))
              (if (and (< (+ base 1) (string-length line))
                       (equal? (string-ref line base) "(")
                       (equal? (string-ref line (+ base 1)) "("))
                  (collect-let-bindings line (+ base 1) (string-length line) '())
                  '())))
          '()))))

(define (extract-binding-line-info line)
  (let ((trimmed (trim-left line)))
    (let ((indent (leading-space-count line)))
      (if (and (> (string-length trimmed) 1)
               (equal? (string-ref trimmed 0) "("))
          (with-indent (parse-name-at trimmed 1) indent)
          #f))))

(define (let-start-line? line)
  (let ((trimmed (trim-left line)))
    (or (starts-with? trimmed "(let (")
        (starts-with? trimmed "(let(")
        (starts-with? trimmed "(let\t("))))

(define (find-col-for-symbol symbol infos)
  (if (null? infos)
      #f
      (let ((info (car infos)))
        (if (equal? symbol (car info))
            (car (cdr info))
            (find-col-for-symbol symbol (cdr infos))))))

(define (find-definition-info symbol lines idx in-let-bindings)
  (if (null? lines)
      #f
      (let ((line (car lines)))
        (if in-let-bindings
            (let ((binding (extract-binding-line-info line)))
              (if (and binding (equal? symbol (car binding)))
                  (list idx (car (cdr binding)))
                  (find-definition-info
                    symbol
                    (cdr lines)
                    (+ idx 1)
                    (not (contains-substring line "))")))))
            (let ((define-info (extract-define-info line)))
              (if (and define-info (equal? symbol (car define-info)))
                  (list idx (car (cdr define-info)))
                  (let ((macro-info (extract-defmacro-info line)))
                    (if (and macro-info (equal? symbol (car macro-info)))
                        (list idx (car (cdr macro-info)))
                        (let ((let-col (find-col-for-symbol symbol (extract-let-binding-infos line))))
                          (if (eq? let-col #f)
                              (find-definition-info
                                symbol
                                (cdr lines)
                                (+ idx 1)
                                (and (let-start-line? line)
                                     (not (contains-substring line "))"))))
                              (list idx let-col)))))))))))

(define (find-definition-location uri text symbol)
  (let ((info (find-definition-info symbol (string-split text "\n") 0 #f)))
    (if (eq? info #f)
        'null
        (let ((line (car info)))
          (let ((col (car (cdr info))))
            (make-location uri (make-range line col line (+ col (string-length symbol)))))))))

; ============================================================================
; LSP Handler
; ============================================================================

(define (handle-definition-request state params id)
  (let ((text-doc (safe-json-get params "textDocument")))
    (let ((position (safe-json-get params "position")))
      (let ((uri (safe-json-get text-doc "uri")))
        (let ((line (safe-json-get position "line"))
              (character (safe-json-get position "character")))
          (if (or (json-null? uri)
                  (json-null? line)
                  (json-null? character)
                  (not (number? line))
                  (not (number? character)))
              (list state (make-response id 'null))
              (let ((text (get-document state uri)))
                (if (or (not text) (json-null? text))
                    (list state (make-response id 'null))
                    (let ((symbol (symbol-at-position text line character)))
                      (if (or (not symbol) (equal? symbol ""))
                          (list state (make-response id 'null))
                          (list state (make-response id (find-definition-location uri text symbol)))))))))))))
