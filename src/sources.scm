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
  (chb-import base-directories misc ranking)
  (use extras files posix ports data-structures srfi-1 srfi-69)

  ; Associates source names with its informations.
  (define source-table (make-hash-table))

  ;; Stores the following informations about a source:
  ;; thunk A function, which returns the contents of the source in form of
  ;;       a string list.
  ;; async A boolean, which specifies whether a source's result should be
  ;;       cached by a background process for subsequent runs.
  (define-record source-info thunk async)

  ;; If the given source list is empty, it will return a list with all
  ;; sources available.
  (define (fallback-source-list source-list)
    (if (null? source-list)
      (map car (hash-table->alist source-table))
      source-list))

  ;; Registers a source and errors if it is already registered. It takes
  ;; optional key values as described above in 'source-info'.
  (define (register-source name thunk #!key async)
    (cond
      ((substring-index name ">  ")
       (die "source name cannot contain the '>  ' separator: '" name "'."))
      ((hash-table-exists? source-table name)
       (die
         "multiple sources with the same name are forbidden: '" name "'."))
      (else
        (hash-table-set!
          source-table name
          (make-source-info thunk async)))))

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
            (reverse (source-function)))))
      (file-move
        (get-cache-path ".async/" name "/.cache")
        (get-cache-path ".async/" name "/cache") #t)
      (close-output-port lock-port)))

  ;; Read lines in reversed order. This is slightly faster than
  ;; 'read-lines' from extras.
  (define (read-lines-reversed filename)
    (call-with-input-file filename
      (lambda (in)
        (port-fold
          cons '()
          (lambda () (read-line in))))))

  ;; Returns the raw contents of a source. If the 'async' flag is set for
  ;; this source, it will return its cache. If no cache is available, it
  ;; will create one and block until its done.
  (define (collect-source-contents name info)
    (if (source-info-async info)
      (let ((cache-file (get-cache-path ".async/" name "/cache")))
        (if (file-exists? cache-file)
          (let ((cache-data (read-lines-reversed cache-file)))
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

  ;; A wrapper around 'collect-source-contents', which filters out all
  ;; items with a score.
  (define (collect-ranked-source-contents name info)
    (let ((source-content (collect-source-contents name info))
          (score-alist (get-score-alist name)))
      (if score-alist
        (let ((filter-table (alist->hash-table score-alist)))
          (filter
            (lambda (item)
              (cond
                ((zero? (hash-table-size filter-table)) #t)
                ((hash-table-exists? filter-table item)
                 (hash-table-delete! filter-table item)
                 #f)
                (else #t)))
            source-content))
        source-content)))

  ;; Returns the content of a source as an alist, which associates each
  ;; item with its source name. The returned alist does not contain ranked
  ;; items.
  (define (gather-source name)
    (define info (hash-table-ref source-table name))
    (map
      (lambda (item) (cons item name))
      (collect-ranked-source-contents name info)))

  ;; Gathers the contents of all sources in the given source list, without
  ;; scored items. If the list is empty, it will gather all available
  ;; sources. If the list is not empty, it must contain only valid source
  ;; names. Duplicates will be ignored.
  (define (gather-from-source-list source-list)
    (fold
      (lambda (source-name lst)
        (merge
          (gather-source source-name) lst
          (lambda (a b)
            (< (string-length (car a))
               (string-length (car b))))))
      '()
      ; Deduplicate list of sources.
      (let
        ((sorted-list (sort (fallback-source-list source-list) string<?)))
        (fold
          (lambda (name lst)
            (if (string=? name (car lst))
              lst
              (cons name lst)))
          (list (car sorted-list))
          (cdr sorted-list)))))

  ;; Builds a new alist from the given score list with the given source
  ;; name and merges it into another. This alist associates a score with a
  ;; pair containing a string and its source.
  (define (merge-scored-lists score-alist source-name lst)
    (merge
      (map
        (lambda (score-pair)
          (cons
            (cdr score-pair)
            (cons (car score-pair) source-name)))
        score-alist)
      lst
      (lambda (a b)
        (> (car a) (car b)))))

  ;; Gathers all informations from the given sources. It takes a list of
  ;; valid, existing source names as an optional argument. If it is omitted
  ;; or null, it will return the contents of all available sources.
  (define (gather-sources #!optional (source-list '()))
    (let ((invalid-source (find (complement source-exists?) source-list)))
      (if invalid-source
        (die "source does not exist: '" invalid-source "'")))
    (append
      (map cdr
        (fold
          (lambda (source-name lst)
            (let ((score-alist (get-score-alist source-name)))
              (if score-alist
                (merge-scored-lists score-alist source-name lst)
                lst)))
          '() (fallback-source-list source-list)))
      (gather-from-source-list source-list))))
