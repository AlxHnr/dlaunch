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

(chb-module misc (die get-formatted-count)
  (use ports irregex data-structures srfi-1 srfi-13)

  ;; Applies print on the given arguments with current output port set to
  ;; stderr, and terminate the program with failure.
  (define (die #!rest message)
    (with-output-to-port (current-error-port)
      (lambda ()
        (apply print message)))
    (exit 1))

  ;; A pattern for matching numbers without the thousands seperator.
  (define pattern (irregex "^(\\d+)(\\d{3})((\\.\\d{3})*)$"))

  ;; Returns the formatted count of elements in the given list with the
  ;; thousands seperator. "1.234" or "98.732.134".
  (define (get-formatted-count lst)
    (let replace-num-groups
      ((str (number->string (count (constantly #t) lst))))
      (if (irregex-match pattern str)
        (replace-num-groups (irregex-replace pattern str 1 "." 2 3))
        str))))
