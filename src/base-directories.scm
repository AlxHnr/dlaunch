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

;; This module helps to manage base paths and files and respects path
;; environment variables specified by the XDG Base Directory Specification.

(chb-module base-directories
  (get-config-path get-cache-path get-data-path)
  (use files)

  ;; Determines a path from the environment.
  (define (build-path-from-env xdg-var-name fallback-string)
    (define xdg-path
      (get-environment-variable
        (string-append "XDG_" xdg-var-name "_HOME")))
    (string-append
      (if (and xdg-path
               (> (string-length xdg-path) 0)
               (absolute-pathname? xdg-path))
        xdg-path
        (string-append
          (get-environment-variable "HOME") "/" fallback-string))
      "/dlaunch/"))

  ;; Contains various paths to special user directories.
  (define config-dir-path (build-path-from-env "CONFIG" ".config"))
  (define cache-dir-path  (build-path-from-env "CACHE"  ".cache"))
  (define data-dir-path   (build-path-from-env "DATA"   ".local/share"))

  ;; These functions append all passed strings to a specific directory
  ;; path, which can be used by dlaunch plugins to store their data in.
  (define (get-config-path #!rest rest)
    (apply string-append (cons config-dir-path rest)))
  (define (get-cache-path #!rest rest)
    (apply string-append (cons cache-dir-path rest)))
  (define (get-data-path #!rest rest)
    (apply string-append (cons data-dir-path rest))))
