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

(chb-module ranking (get-score-alist learn-selected-pair)
  (chb-import base-directories)
  (use extras posix srfi-1 srfi-69)

  ;; The path to the score file.
  (define score-file-path (get-data-path "score-file.scm"))

  ;; Adds one learning step to the given score.
  (define (increase-score score)
    (+ score (* (- 1.0 score) 0.1)))

  ;; Decreases the score by the given amount of days past.
  (define (decrease-score score days-past)
    (let ((decay-day (+ (sqrt (* (- (- score 1)) 1000)) days-past)))
      (add1 (- (/ (expt decay-day 2) 1000)))))

  ; Capture the startup time.
  (define startup-timestamp (current-seconds))

  ;; Updates all scores in the given alist by the amount of days passed.
  (define (update-alist alist days-past)
    (filter-map
      (lambda (info-pair)
        (let ((new-score (decrease-score (cdr info-pair) days-past)))
          (if (<= new-score 0.0)
            #f (cons (car info-pair) new-score))))
      alist))

  ;; Reads a score file and returns an alist, which associates source names
  ;; with score alists. These alists again map strings to their scores. All
  ;; scores will be recomputed against the delta of passed days since the
  ;; last scoring.
  (define (read-score-file path)
    (define file-content (read-file path))
    (define days-past
      (if (< (car file-content) startup-timestamp)
        (/ (- startup-timestamp (car file-content))
           (* 60 60 24))
        0.0))
    (fold
      (lambda (old-alist lst)
        (let ((new-alist (update-alist (cdr old-alist) days-past)))
          (if (null? new-alist)
            lst
            (cons
              (cons (car old-alist) new-alist)
              lst))))
      '() (cdr file-content)))

  ;; This alist contains all scores of all sources.
  (define source-score-alist
    (if (file-exists? score-file-path)
      (read-score-file score-file-path)
      '()))

  ;; Saves the content of 'source-score-alist' in 'score-file-path'.
  (define (save-score-alist)
    (create-directory (get-data-path))
    (call-with-output-file
      score-file-path
      (lambda (out)
        (write-line "; Timestamp of last scoring:" out)
        (write-line (number->string startup-timestamp) out)
        (for-each
          (lambda (source-scores)
            (newline out)
            (write-line
              (string-append
                "; Scores for the source '" (car source-scores) "':")
              out)
            (pretty-print source-scores out))
          source-score-alist))))

  ;; Returns the score alist for the given source. This function returns
  ;; false if there are no scores.
  (define (get-score-alist source-name)
    (let ((association (assoc source-name source-score-alist)))
      (if association
        (cdr association) #f)))

  ;; Returns a score pair, containing a string and its initial score.
  (define (new-score-pair selected-pair)
    (cons
      (car selected-pair)
      (increase-score 0.0)))

  ;; Learns the content of the given pair, which must contain two valid
  ;; strings. It will update the score alist and save it to
  ;; 'score-file-path'.
  (define (learn-selected-pair selected-pair)
    (define score-alist
      (assoc (cdr selected-pair) source-score-alist))
    (if (not score-alist)
      (set!
        source-score-alist
        (cons
          (list
            (cdr selected-pair)
            (new-score-pair selected-pair))
          source-score-alist))
      (let ((score-pair (assoc (car selected-pair) (cdr score-alist))))
        (if score-pair
          (set-cdr! score-pair (increase-score (cdr score-pair)))
          (set-cdr!
            score-alist
            (cons (new-score-pair selected-pair) (cdr score-alist))))))
    (save-score-alist)))
