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

;; This module provides high level wrapper functions around dmenu.

(chb-module dlaunch-core
  (dlaunch dlaunch-from-list call-with-dmenu-output-pipe)
  (chb-import base-directories sources)
  (use extras posix data-structures srfi-1)

  ;; Custom arguments specified by the user in dlaunch's config files.
  (define dmenu-user-args
    (if (file-exists? (get-config-path "dmenu-args.scm"))
      (read-file (get-config-path "dmenu-args.scm"))
      '()))

  ;; Builds a list with dlaunch specific command line arguments for dmenu.
  (define (get-dlaunch-args lst)
    (let ((list-length (count (constantly #t) lst)))
      (list "-l" "10" "-p"
            (string-append
              "Dlaunch (" (number->string list-length) " items)"))))

  ;; Selects a string using dmenu. It takes a procedure, which will be
  ;; called with an output port to write lines to dmenu. It takes two
  ;; optional lists as arguments. 'extra-args' contains args, which may be
  ;; overridden by 'dmenu-user-args'. Arguments in 'dmenu-args' have the
  ;; highest priority and override everything else. It returns either the
  ;; users input as a string, or #f.
  (define (call-with-dmenu-output-pipe
            proc #!key (extra-args '()) (dmenu-args '()))
    (define-values (dmenu-in dmenu-out dmenu-pid)
      (process "dmenu" (append extra-args dmenu-user-args dmenu-args)))
    (proc dmenu-out)
    (close-output-port dmenu-out)
    (define selected-string (read-line dmenu-in))
    (close-input-port dmenu-in)
    (if (eof-object? selected-string)
      #f selected-string))

  ;; Prompts the user to pick one string from a given list and returns it.
  ;; If the user aborts his selection, it returns #f. This function takes
  ;; an optional list of arguments for dmenu.
  (define (dlaunch-from-list lst #!optional (dmenu-args '()))
    (call-with-dmenu-output-pipe
      (lambda (out)
        (for-each
          (lambda (str)
            (write-line str out))
          lst))
      extra-args: (get-dlaunch-args lst)
      dmenu-args: dmenu-args))

  ;; Prompts the user to select a string from the specified sources and
  ;; returns it as a pair, with its source name as the cdr. If the users
  ;; input string does not exist in any source, the sources name will be
  ;; #f. If the user aborts his selection, #f will be returned. This
  ;; function takes a list of source names as a key parameter, to specify
  ;; the sources which should be searched. If the source list is omitted or
  ;; null, it will search trough all available sources. This function also
  ;; takes an optional list of arguments for dmenu as a key parameter.
  (define (dlaunch #!key (sources '()) (dmenu-args '()))
    (define source-contents (gather-sources sources))
    (define selected-string
      (call-with-dmenu-output-pipe
        (lambda (out)
          (for-each
            (lambda (item-pair)
              (write-line
                (string-append (cdr item-pair) ">  " (car item-pair))
                out))
            source-contents))
        extra-args: (get-dlaunch-args source-contents)
        dmenu-args: dmenu-args))
    (if selected-string
      (let ((seperator-index (substring-index ">  " selected-string)))
        (if seperator-index
          (cons
            (substring selected-string (+ 3 seperator-index))
            (substring selected-string 0 seperator-index))
          (cons selected-string #f)))
      #f)))
