#lang racket

(require ffi/unsafe
         ffi/unsafe/define)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define-metal create-metal-adder
              (_fun _string -> _pointer)
              #:c-id createMetalAdder)

(define-metal perform-computation
              (_fun _pointer -> _void)
              #:c-id performComputation)

(define adder (create-metal-adder  (string-append (path->string (current-directory)) "Build/Products/Debug/default.metallib")))

(perform-computation adder)
