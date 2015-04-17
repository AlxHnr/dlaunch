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

(chb-module plugin-loader (compile-changed-plugins load-plugins)
  (chb-import base-directories misc)
  (use utils files extras posix srfi-1 srfi-13 srfi-69)

  ;; A hash table, which contains the names of all loaded plugins.
  (define loaded-plugins (make-hash-table))

  ;; The full path to the file containing compilation informations.
  (define build-data-file (get-cache-path "compiled-plugins.scm"))

  ;; A hash table, which associates plugin names with the last modification
  ;; time of the corresponding plugin.
  (define build-data
    (if (file-exists? build-data-file)
      (alist->hash-table (car (read-file build-data-file)))
      (make-hash-table)))

  ;; The directory path to the plugin-api import libraries.
  (define-constant plugin-api-import-path
    (string-append
      (or (get-environment-variable "INSTALL_PREFIX") "/usr/local")
      "/lib/dlaunch/plugin-api/"))

  ;; Calls the given procedure for each plugin with the current working
  ;; directory set to the plugin-api import path. The given procedure takes
  ;; three arguments: the plugin name, the full path to its source file and
  ;; the full path to its output file.
  (define (for-each-plugin-with-chdir proc)
    (let ((pwd (current-directory)))
      (change-directory plugin-api-import-path)
      (for-each
        (lambda (filename)
          (proc
            (pathname-file filename)
            (get-config-path "plugins/" filename)
            (get-cache-path "plugins/" (pathname-file filename) ".so")))
        (if (directory-exists? (get-config-path "plugins/"))
          (filter
            (lambda (filename) (string-suffix-ci? ".scm" filename))
            (directory (get-config-path "plugins/")))
          '()))
      (change-directory pwd)))

  ;; Compiles a scheme file for dynamic loading.
  (define (compile-scheme-file plugin-name source-file output-file)
    (compile-file
      source-file
      options: (list "-O3" "-dynamic" "-unit" plugin-name)
      output-file: output-file load: #f))

  ;; Checks if the source file for the given plugin has changed and
  ;; rebuilds the corresponding dynamic library. If the dynamic library
  ;; does not not exist it will be created. The path to the output file
  ;; must exist.
  (define (update-compiled-plugin plugin-name source-file output-file)
    (define curr-time (vector-ref (file-stat source-file) 8))
    (define prev-time (hash-table-ref/default build-data plugin-name 0))
    (unless (and (file-exists? output-file) (= prev-time curr-time))
      (print "compiling plugin: " plugin-name " ...")
      (if (compile-scheme-file plugin-name source-file output-file)
        (hash-table-set! build-data plugin-name curr-time)
        (die "failed to compile plugin: " plugin-name))))

  ;; Compiles all plugins, which either don't exist or have been modified
  ;; since their last compilation.
  (define (compile-changed-plugins)
    (create-directory (get-cache-path "plugins/") #t)
    (for-each-plugin-with-chdir update-compiled-plugin)
    (call-with-output-file
      build-data-file
      (lambda (out)
        (write (hash-table->alist build-data) out))))

  ;; Loads a plugin if it was not loaded already.
  (define (load-plugin plugin-name source-file output-file)
    (unless (hash-table-exists? loaded-plugins plugin-name)
      (load-library (string->symbol plugin-name) output-file)
      (hash-table-set! loaded-plugins plugin-name #t)
      (print "loaded plugin: " plugin-name)))

  ;; Loads all plugins, which were not loaded already.
  (define (load-plugins)
    (for-each-plugin-with-chdir load-plugin)))
