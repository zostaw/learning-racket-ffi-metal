#lang racket

(require ffi/unsafe
         ffi/unsafe/define)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define-metal create-metal-adder
              (_fun -> _pointer)
              #:c-id createMetalAdder)

(define-metal perform-computation
              (_fun _pointer -> _void)
              #:c-id performComputation)

(define adder (create-metal-adder))

(perform-computation adder)
