#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         racket/flonum)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define metallib-path
  (string-append (path->string (current-directory))
                 "Build/Products/Debug/default.metallib"))

(define-metal create-metal-device
  (_fun _string -> _pointer)
  #:c-id createMetalDevice)

(define-metal create-metal-adder
  (_fun _string -> _pointer)
  #:c-id createMetalAdder)

(define-metal perform-computation
  (_fun _pointer -> _void)
  #:c-id performComputation)

(define-metal perform-computation-with-inputs
  (_fun _pointer
        [vecA : (_vector i _float)]
        [_int = (vector-length vecA)]
        [vecB : (_vector i _float)]
        [_int = (vector-length vecB)]
        -> _void)
  #:c-id performComputationWithInputs)

(define-metal vector->mvector
  (_fun _pointer
        [vec : (_vector i _float)]
        [_int = (vector-length vec)]
        -> _pointer)
  #:c-id metalVector)

(define (define-mvector mdevice)
  (lambda (vector) (vector->mvector mdevice vector)))




;; OO API
(define adder (create-metal-adder  metallib-path))
(define dataA (make-vector (expt 2 24) 1.0))
(define dataB (make-vector (expt 2 24) 2.0))

(perform-computation-with-inputs adder dataA dataB)


;; functional API
(define mdevice (create-metal-device metallib-path))
(define mvector (define-mvector mdevice))

(define mvector-A (mvector (make-vector (expt 2 24) 1.0)))
(define mvector-B (mvector (make-vector (expt 2 24) 2.0)))


(struct Tensor (weights bias forward)
  #:transparent)

;(define tensor (Tensor weights bias (λ (X) (plus (times weights X) bias))))
