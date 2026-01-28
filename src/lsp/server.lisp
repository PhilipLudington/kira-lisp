; Kira Lisp LSP Server
; Entry point for the language server
;
; Usage: kira run src/main.ki run src/lsp/server.lisp

(import "src/lsp/main.lisp")

; Start the server and discard the final state
(let ((_ (lsp-main)))
  '())
