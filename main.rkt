#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         racket/flonum)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define metallib-path
  (string-append (path->string (current-directory))
                 "Build/Products/Debug/default.metallib"))


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





(define adder (create-metal-adder  metallib-path))
(define dataA (make-vector (expt 2 24) 1.0))
(define dataB (make-vector (expt 2 24) 2.0))

(perform-computation-with-inputs adder dataA dataB)
