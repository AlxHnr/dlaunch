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

(chb-module sources (register-source source-exists? gather-sources)
  (chb-import base-directories misc)
  (use extras files posix data-structures srfi-1 srfi-69)

  ; Associates source names with its informations.
  (define source-table (make-hash-table))

  ;; Stores the following informations about a source:
  ;; thunk A function, which returns the contents of the source in form of
  ;;       a string list.
  ;; async A boolean, which specifies whether a source's result should be
  ;;       cached by a background process for subsequent runs.
  ;; once  A boolean, which when true will cause all collections of this
  ;;       source to return the result of its first invocation. This cache
  ;;       vanishes if Dlaunch terminates and is only useful for plugins
  ;;       which may gather a source multiple times.
  (define-record source-info thunk async once)

  ; Cached results for source which should only be executed once.
  (define source-cache (make-hash-table))

  ;; Registers a source and errors if it is already registered. It takes
  ;; optional key values as described above in 'source-info'.
  (define (register-source name thunk #!key async once)
    (cond
      ((substring-index name ">  ")
       (die "source name cannot contain the '>  ' separator: '" name "'."))
      ((hash-table-exists? source-table name)
       (die
         "multiple sources with the same name are forbidden: '" name "'."))
      (else
        (hash-table-set!
          source-table name
          (make-source-info thunk async once)))))

  ;; Checks if a source was registered.
  (define (source-exists? name)
    (hash-table-exists? source-table name))

  ;; Update the cache, if it is not being updated already by another
  ;; process. It takes the name of the source and its source function as
  ;; arguments. If 'wait' is true, it will wait for running background
  ;; processes to terminate.
  (define (synced-cache-update name source-function wait)
    (create-directory (get-cache-path ".async/" name) #t)
    (define lock-port
      (open-output-file (get-cache-path ".async/" name "/lockfile")))
    (define lock
      (condition-case
        (file-lock lock-port)
        ((exn file)
         (if wait
           (file-unlock (file-lock/blocking lock-port)))
         (close-output-port lock-port)
         #f)))
    (when lock
      (call-with-output-file
        (get-cache-path ".async/" name "/.cache")
        (lambda (out)
          (for-each
            (lambda (item)
              (write-line item out))
            (source-function))))
      (file-move
        (get-cache-path ".async/" name "/.cache")
        (get-cache-path ".async/" name "/cache") #t)
      (close-output-port lock-port)))

  ;; Returns the raw contents of a source. If the 'async' flag is set for
  ;; this source, it will return its cache. If no cache is available, it
  ;; will create one and block until its done.
  (define (collect-source-contents name info)
    (if (source-info-async info)
      (let ((cache-file (get-cache-path ".async/" name "/cache")))
        (if (file-exists? cache-file)
          (begin
            (define cache-data (read-lines cache-file))
            (process-fork
              (lambda ()
                (synced-cache-update
                  name (source-info-thunk info) #f)))
            cache-data)
          (begin
            (print "initializing cache for the source '" name "' ...")
            (synced-cache-update name (source-info-thunk info) #t)
            (read-lines cache-file))))
      ((source-info-thunk info))))

  ;; Returns the content of a source as an alist, which associates each
  ;; item with its source name. It considers the sources 'once' flag.
  (define (gather-source name)
    (define info (hash-table-ref source-table name))
    (map
      (lambda (item) (cons item name))
      (if (source-info-once info)
        (if (hash-table-exists? source-cache name)
          (hash-table-ref source-cache name)
          (begin
            (define result (collect-source-contents name info))
            (hash-table-set! source-cache name result)
            result))
        (collect-source-contents name info))))

  ;; Gathers all informations from the given sources. It takes a list of
  ;; valid, existing source names as an optional argument. If it is omitted
  ;; or null, it will return the contents of all available sources.
  (define (gather-sources #!optional (source-list '()))
    (define invalid-source
      (find (complement source-exists?) source-list))
    (if invalid-source
      (die "source does not exist: '" invalid-source "'"))
    (fold
      (lambda (source-name lst)
        (merge
          (gather-source source-name) lst
          (lambda (a b)
            (< (string-length (car a))
               (string-length (car b))))))
      '()
      (if (null? source-list)
        (map car (hash-table->alist source-table))
        ; Deduplicate source list.
        (let ((sorted-list (sort source-list string<?)))
          (fold
            (lambda (name lst)
              (if (string=? name (car lst))
                lst
                (cons name lst)))
            (list (car sorted-list))
            (cdr sorted-list)))))))
