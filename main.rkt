#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         ffi/cvector
         ffi/unsafe/cvector
         racket/flonum)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define metallib-path
  (string-append (path->string (current-directory))
                 "Build/Products/Debug/default.metallib"))


(define _metal_data_type
  (_enum '(FLOAT = 0
           INT32 = 1)
         _uint32
         #:unknown (lambda (x)
                     (cond [(eq? x 'FLOAT)  0]
                           [(eq? x 'INT32) 1]
                           [else (error 'metal_data_type "unknown enum value")]))))


(define-cstruct _metal_vector
                ([buffer_ptr    _pointer]
                 [buffer_len    _pointer]
                 [data_type     _metal_data_type))

(define-metal create-metal-device
  (_fun _string -> _pointer)
  #:c-id createMetalDevice)



(define-metal create-metal-library
  (_fun _pointer _string -> _pointer)
  #:c-id createMetalLibrary)



(define-metal create-metal-adder
  (_fun _string -> _pointer)
  #:c-id createMetalAdder)



(define-metal perform-computation
  (_fun _pointer -> _void)
  #:c-id performComputation)



(define-metal compute-add-orig
  (_fun _pointer
        _pointer
        _pointer
        _pointer
        _pointer
        -> _bool)
  #:c-id computeAdd)

(define (compute-add mdevice mlibrary mvector-A mvector-B mvector-result)
  (let ([result (compute-add-orig mdevice mlibrary mvector-A mvector-B mvector-result)])
    (if (not result)
        (error "ComputeAdd returned error.")
        mvector-result)))


(define-metal perform-computation-with-float-inputs
  (_fun _pointer
        ;; [vecA : (_vector i _float)]
        ;; [_int = (vector-length vecA)]
        [vecA : _cvector]
        [_int = (cvector-length vecA)]
        ;; [vecB : (_vector i _float)]
        ;; [_int = (vector-length vecB)]
        [vecB : _cvector]
        [_int = (cvector-length vecB)]
        -> _void)
  #:c-id performComputationWithFloatInputs)



(define-metal vector->mvector
  (_fun _pointer
        [vec : (_vector i _float)]
        [_int = (vector-length vec)]
        -> _pointer)
  #:c-id metalVector)

(define (mvector-definer mdevice)
  (lambda (vector) (vector->mvector mdevice vector)))



(define-metal int32-vector->mvector
  (_fun _pointer
        [vec : (_vector i _int32)]
        [_int = (vector-length vec)]
        -> _pointer)
  #:c-id metalInt32Vector)

(define (int32-mvector-definer mdevice)
  (lambda (vector) (int32-vector->mvector mdevice vector)))




(define-metal cvector->mvector
  (_fun _pointer
        ;_cvector
        [vec : _cvector]
        [_int = (cvector-length vec)]
        -> _pointer)
  #:c-id metalVector)


(define _float_ptr
  (_cpointer _float))

(define-metal mvector->cvector
  (_fun _pointer
        -> _float_ptr)
  #:c-id getCVector)




(define-metal make-mvector-orig
  (_fun _pointer ; device
        _int32 ; type-id
        _int32 ; size
        -> _pointer)
  #:c-id makeMetalVector)

(define (make-mutable-mvector mdevice type size)
  (let ([type-id (match type
                ['float 0]
                ['int32 0]
                [_ (error (format "Type ~a not supported, choose one of: 'float 'int32\n" type))])])
    (make-mvector-orig mdevice type-id size)))




;; OO API
(define adder (create-metal-adder  metallib-path))
;; (define dataA (make-vector (expt 2 24) 1.0))
(define dataA (list->cvector 
                (make-list (expt 2 24) 1.0)
                _float))
;; (define dataB (make-vector (expt 2 24) 2.0))
(define dataB (list->cvector 
                (make-list (expt 2 24) 2.0) 
                _float))

(perform-computation-with-float-inputs adder dataA dataB)




;; functional API
(define mdevice (create-metal-device metallib-path))
(define mlibrary (create-metal-library mdevice metallib-path))


(define vector-size (expt 2 24))

(define cvector-A (list->cvector 
                    (make-list vector-size 1.0)
                    _float))
(define mvector-A (cvector->mvector mdevice cvector-A))

(define cvector-B (list->cvector 
                    (make-list vector-size 2.0) 
                    _float))
(define mvector-B (cvector->mvector mdevice cvector-B))

(define mvector-result (make-mutable-mvector mdevice 'float vector-size))


(compute-add mdevice mlibrary mvector-A mvector-B mvector-result)

(define results (mvector->cvector mvector-result))


(let ([n 10])
  (displayln
 (format "First ~a thingies:  ~a"
         n
         (map (λ (i)
                (ptr-ref results _float i))
              (range n))
         )))

;; (perform-computation-with-inputs adder dataA dataB)

(struct Tensor (weights bias forward)
  #:transparent)

;(define tensor (Tensor weights bias (λ (X) (plus (times weights X) bias))))
