; Copyright (c) 2014 Alexander Heinrich <alxhnr@nudelpost.de>
;
; This software is provided 'as-is', without any express or implied
; warranty. In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
;    1. The origin of this software must not be misrepresented; you must
;       not claim that you wrote the original software. If you use this
;       software in a product, an acknowledgment in the product
;       documentation would be appreciated but is not required.
;
;    2. Altered source versions must be plainly marked as such, and must
;       not be misrepresented as being the original software.
;
;    3. This notice may not be removed or altered from any source
;       distribution.

(chb-module handler (register-handler apply-handler)
  (use srfi-69)

  ;; A list, containing all handler procedures.
  (define handler-procs '())

  ;; Registers a handler. A handler is a procedure, which takes two
  ;; arguments. The first argument is the users input string. The second
  ;; argument is either the name of its source or #f.
  (define (register-handler proc)
    (set! handler-procs (cons proc handler-procs)))

  ;; Applies all available handler to the given source pair.
  (define (apply-handler selected-string source-name)
    (for-each
      (lambda (proc)
        (proc selected-string source-name))
      handler-procs)))
