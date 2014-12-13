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

(chb-program
  (chb-import dlaunch-core plugin-loader handler)
  (use data-structures srfi-1 srfi-13)

  (define (print-help)
    (print "Usage: dlaunch [OPTION]...\n"
    "A dmenu wrapper, which allows you to search trough various"
    " sources.\n\n"
    "  --sources=NAMES\t\tSearch only trough the specified sources.\n"
    "\t\t\t\tMultiple sources are separated by a comma.\n"
    "  --compile\t\t\t(Re)compile modified plugins and exit.\n"
    "  --help\t\t\tShow this help and exit."))

  (define-values (dlaunch-args dmenu-args)
    (partition
      (lambda (argument)
        (cond
          ((string-prefix? "--sources=" argument) #t)
          ((string-prefix? "--compile" argument)
           (compile-changed-plugins)
           (exit))
          ((string-prefix? "--help" argument)
           (print-help)
           (exit))
          (else #f)))
      (command-line-arguments)))

  (define specified-sources
    (fold
      (lambda (argument source-list)
        (if (string-prefix? "--sources=" argument)
          (fold
            cons source-list
            (string-split (substring argument 10) ","))
          source-list))
      '() dlaunch-args))

  (compile-changed-plugins)
  (load-plugins)
  (define user-selection
    (dlaunch
      sources: specified-sources
      dmenu-args: dmenu-args))
  (if user-selection
    (apply-handler
      (car user-selection)
      (cdr user-selection))))
