#lang racket
(require "metal-ffi.rkt")

(provide (all-defined-out))
(require flomat)
(require racket/vector)
(define metal-config (initialize-metal metallib-path))

#|
  Tensor:
    weights (out-dim, inp-dim)
    bias    (out-dim,)
    forward (λ (X) (weights·X + b)
|#
(struct Tensor (weights bias forward)
  #:transparent)


#|
  Tensor definition on flomat
|#
(define-syntax (define-tensor stx)
  (syntax-case stx ()
    [(_ out-dim inp-dim)
    (with-syntax ([weights (datum->syntax stx 'weights)]
                  [bias (datum->syntax stx 'bias)])
      #'(let ([weights (list->flomat (for/list ([row (in-range out-dim)])
                                       (for/list ([col (in-range inp-dim)])
                                         (random))))]
              [bias (list->flomat (for/list ([row (in-range out-dim)])
                                    (list (random))))])
          (Tensor weights bias (λ (X) (plus (times weights X) bias)))))]))

(define-syntax (random-input stx)
  (syntax-case stx ()
    [(_ dim)
     (with-syntax ([input (datum->syntax stx 'input)])
       #'(let ([input (list->flomat (for/list ([row (in-range dim)])
                                      (list (random))))])
       input))]))


#|
  Tensor definition on vector
|#
(define-syntax (define-tensor-vec stx)
  (syntax-case stx ()
    [(_ out-dim inp-dim)
    (with-syntax ([weights (datum->syntax stx 'weights)]
                  [bias (datum->syntax stx 'bias)])
      #'(let ([weights (for/vector ([row (in-range out-dim)])
                         (for/vector ([col (in-range inp-dim)])
                           (random)))]
              [bias (for/vector ([row (in-range out-dim)])
                      (vector (random)))])
          (Tensor weights bias (λ (X) (plus (times weights X) bias)))))]))

(define-syntax (random-input-vec stx)
  (syntax-case stx ()
    [(_ dim)
     (with-syntax ([input (datum->syntax stx 'input)])
       #'(let ([input (for/vector ([row (in-range dim)])
                                      (vector (random)))])
       input))]))


#|
  Tensor definition on metal
|#
(define-syntax (define-metal-tensor stx)
  (syntax-case stx ()
    [(_ out-dim inp-dim)
    (with-syntax ([weights (datum->syntax stx 'weights)]
                  [bias (datum->syntax stx 'bias)])
      #'(let ([weights (list->mmatrix metal-config (for/list ([row (in-range out-dim)])
                                       (for/list ([col (in-range inp-dim)])
                                         (random))))]
              [bias (list->mmatrix metal-config (for/list ([row (in-range out-dim)])
                                    (list (random))))])
          (Tensor weights bias (λ (X) (compute-mat-add metal-config (compute-mat-mul metal-config weights X) bias)))))]))

(define-syntax (random-metal-input stx)
  (syntax-case stx ()
    [(_ dim)
     (with-syntax ([input (datum->syntax stx 'input)])
       #'(let ([input (list->mmatrix metal-config (for/list ([row (in-range dim)])
                                                    (list (random))))])
           input))]))






#| Benchmark

   They're basically the same on flomat and vector, and a improvement of 3-6x on metal...
   To be fair, I expected it to be much better, at least 1 order of magnitude better.
   My kernel isn't optimized, though - I just did it to learn how does one communicate with Metal from Racket
    and because I was curious what the improvement would be in the most basic scenario.

   Results 1:
       Flomat: 195.611083984375
       Vector: 181.384033203125
       Metal: 30.556884765625

   Results 2:
       Flomat: 176.68701171875
       Vector: 177.373046875
       Metal: 48.281982421875

   Results 3:
       Flomat: 170.9189453125
       Vector: 170.1669921875
       Metal: 31.268798828125
   Results 4:
       Flomat: 179.22509765625
       Vector: 167.153076171875
       Metal: 52.55712890625

   Results 5:
       Flomat: 173.863037109375
       Vector: 168.3330078125
       Metal: 27.2109375
|#
(module+ benchmark
  (require benchmark)
  (define out-dim 1e3)
  (define inp-dim 1e5)

  ; flomat
  (define tensor (define-tensor out-dim inp-dim))
  (define input (random-input inp-dim))

  ; vector
  (define tensor-vec (define-tensor out-dim inp-dim))
  (define input-vec (random-input inp-dim))

  ; vector
  (define tensor-metal (define-metal-tensor out-dim inp-dim))
  (define input-metal (random-metal-input inp-dim))



  ; time it
  (displayln (format "Results:\n    Flomat: ~a\n    Vector: ~a\n    Metal: ~a\n"
                     (let ([start (current-inexact-milliseconds)])
                       ((Tensor-forward tensor) input)
                       (- (current-inexact-milliseconds) start))

                     (let ([start (current-inexact-milliseconds)])
                       ((Tensor-forward tensor-vec) input-vec)
                       (- (current-inexact-milliseconds) start))

                     (let ([start (current-inexact-milliseconds)])
                       ((Tensor-forward tensor-metal) input-metal)
                       (- (current-inexact-milliseconds) start)))))


