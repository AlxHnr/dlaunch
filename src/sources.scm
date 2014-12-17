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

  ;; Registers a source and errors if it is already registered. It takes
  ;; optional key values as described above in 'source-info'.
  (define (register-source source-name thunk #!key async)
    (cond
      ((substring-index source-name ">  ")
       (die "source name cannot contain the '>  ' separator: '"
            source-name "'."))
      ((hash-table-exists? source-table source-name)
       (die "multiple sources with the same name are forbidden: '"
            source-name "'."))
      (else
        (hash-table-set!
          source-table source-name
          (make-source-info thunk async)))))

  ;; Checks if a source was registered.
  (define (source-exists? source-name)
    (hash-table-exists? source-table source-name))

  ;; Deduplicates the given source list. If the given list is null, it will
  ;; return a list with all registered sources.
  (define (prepare-source-list source-list)
    (if (null? source-list)
      (map car (hash-table->alist source-table))
      (let ((sorted-list (sort source-list string<?)))
        (fold
          (lambda (source-name lst)
            (if (string=? source-name (car lst))
              lst (cons source-name lst)))
          (list (car sorted-list))
          (cdr sorted-list)))))

  ;; Read lines in reversed order. This is slightly faster than
  ;; 'read-lines' from extras.
  (define (read-lines-reversed filename)
    (call-with-input-file filename
      (lambda (in)
        (port-fold
          cons '()
          (lambda () (read-line in))))))

  ;; Update the cache, if it is not being updated already by another
  ;; process. It takes the name of the source and its source function as
  ;; arguments. If 'wait' is true, it will wait for running background
  ;; processes to terminate.
  (define (synced-cache-update source-name source-function wait)
    (create-directory (get-cache-path ".async/" source-name) #t)
    (define lock-port
      (open-output-file
        (get-cache-path ".async/" source-name "/lockfile")))
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
        (get-cache-path ".async/" source-name "/.cache")
        (lambda (out)
          (for-each
            (lambda (item)
              (write-line item out))
            (reverse (source-function)))))
      (file-move
        (get-cache-path ".async/" source-name "/.cache")
        (get-cache-path ".async/" source-name "/cache") #t)
      (close-output-port lock-port)))

  ;; Returns the raw contents of a source. If the 'async' flag is set for
  ;; this source, it will return its cache. If no cache is available, it
  ;; will create one and block until its done.
  (define (collect-source-contents source-name info)
    (if (source-info-async info)
      (let ((cache-file (get-cache-path ".async/" source-name "/cache")))
        (if (file-exists? cache-file)
          (let ((cache-data (read-lines-reversed cache-file)))
            (process-fork
              (lambda ()
                (synced-cache-update
                  source-name (source-info-thunk info) #f)))
            cache-data)
          (begin
            (print
              "initializing cache for the source '" source-name "' ...")
            (synced-cache-update source-name (source-info-thunk info) #t)
            (read-lines cache-file))))
      ((source-info-thunk info))))

  ;; Pair each item in the given list with the given source name.
  (define (attach-source-name lst source-name)
    (map
      (lambda (item)
        (cons item source-name))
      lst))

  ;; Collects all items from a source and returns two values. The first
  ;; value is a list of unscored pairs, associating items with their
  ;; sources. The second returned value is a hash table, containing scored
  ;; items which do not exist in the source at all. If this table is empty,
  ;; the second returned value will be #f.
  (define (get-filtered-source-content source-name info)
    (let ((source-content (collect-source-contents source-name info))
          (score-alist (get-score-alist source-name)))
      (if score-alist
        (let*
          ((filter-table (alist->hash-table score-alist))
           (unscored-items
             (filter
               (lambda (item)
                 (cond
                   ((zero? (hash-table-size filter-table)) #t)
                   ((hash-table-exists? filter-table item)
                    (hash-table-delete! filter-table item)
                    #f)
                   (else #t)))
               source-content)))
          (values
            (attach-source-name unscored-items source-name)
            (if (zero? (hash-table-size filter-table))
              #f filter-table)))
        (values (attach-source-name source-content source-name) #f))))

  ;; Wraps 'get-filtered-source-content' and takes the source info from
  ;; 'source-table'.
  (define (filter-source source-name)
    (get-filtered-source-content
      source-name (hash-table-ref source-table source-name)))

  ;; Returns all existing, and scored items from a source in form of a
  ;; pair list which may be null. The car of each pair contains its score.
  ;; The cdr contains another pair, which associates an item with its
  ;; source name. 'ignore-table' can either be a hash table containing
  ;; items to ignore, or #f.
  (define (get-existing-score-infos source-name ignore-table)
    (let ((score-alist (get-score-alist source-name)))
      (if score-alist
        (map
          (lambda (score-pair)
            (cons
              (cdr score-pair)
              (cons (car score-pair) source-name)))
          (if ignore-table
            (remove
              (lambda (score-pair)
                (hash-table-exists? ignore-table (car score-pair)))
              score-alist)
            score-alist))
        '())))

  ;; Gathers all informations from the given sources. It takes a list of
  ;; valid, existing source names as an optional argument. If it is omitted
  ;; or null, it will return the contents of all available sources.
  (define (gather-sources #!optional (source-list '()))
    (let ((invalid-source (find (complement source-exists?) source-list)))
      (if invalid-source
        (die "source does not exist: '" invalid-source "'")))
    (let*
      ((sorted-source-list (prepare-source-list source-list))
       (final-list-pair
         (fold
           (lambda (source-name list-pair)
             (let-values
               (((content ignore-table) (filter-source source-name)))
               (cons
                 (merge
                   (get-existing-score-infos source-name ignore-table)
                   (car list-pair)
                   (lambda (a b)
                     (> (car a) (car b))))
                 (merge
                   content (cdr list-pair)
                   (lambda (a b)
                     (< (string-length (car a))
                        (string-length (car b))))))))
           (let*-values
             (((content ignore-table)
               (filter-source (car sorted-source-list))))
             (cons
               (get-existing-score-infos
                 (car sorted-source-list) ignore-table)
               content))
           (cdr sorted-source-list))))
      (append
        (map cdr (car final-list-pair))
        (cdr final-list-pair)))))
