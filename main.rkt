#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         ffi/cvector
         ffi/unsafe/cvector)


(define-ffi-definer define-metal
  (ffi-lib "Build/Products/Debug/libMetalComputeBasic"))

(define metallib-path
  (string-append (path->string (current-directory))
                 "Build/Products/Debug/default.metallib"))


(define _metal_data_type
  (_enum '(METAL_FLOAT = 0
           METAL_INT32 = 1)
         _uint32
         #:unknown (lambda (x)
                     (cond [(eq? x 'METAL_FLOAT)  0]
                           [(eq? x 'METAL_INT32) 1]
                           [else (error 'metal_data_type "unknown enum value")]))))


(define-cstruct _metal_vector
                ([buffer_ptr    _pointer]
                 [buffer_len    _size]
                 [data_type     _metal_data_type]))

(define (metal_vector->buffer_ptr metal-vector)
  (ptr-ref metal-vector _pointer 0))
(define (metal_vector->buffer_len metal-vector)
  (ptr-ref metal-vector _size 1))
(define (metal_vector->data_type metal-vector)
  (ptr-ref metal-vector _metal_data_type 2))

(define-cstruct _c_vector
                ([buffer_ptr    _pointer]
                 [buffer_len    _pointer]
                 [data_type     _metal_data_type]))





(define-metal create-metal-device
  (_fun _string -> _pointer)
  #:c-id createMetalDevice)



(define-metal create-metal-library
  (_fun _pointer _string -> _pointer)
  #:c-id createMetalLibrary)





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






(define-metal vector->mvector
  (_fun _pointer
        [vec : (_vector i _float)]
        [_int = (vector-length vec)]
        -> _pointer)
  #:c-id metalVectorObsolete)


(define-metal cvector->mvector
  (_fun _pointer
        [vec : _cvector]
        [_int = (cvector-length vec)]
        -> _pointer)
  #:c-id metalVectorObsolete)





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

(define (make-mvector mdevice type size)
  (let ([type-id (match type
                ['float 0]
                ['int32 0]
                [_ (error (format "Type ~a not supported, choose one of: 'float 'int32\n" type))])])
    (make-mvector-orig mdevice type-id size)))





(define-metal create-mvector
  (_fun _pointer ; device
        [vec : _cvector]
        [_int = (cvector-length vec)]
        _metal_data_type   ; type
        _int32   ; length
        -> _metal_vector)
  #:c-id createMetalVector)








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

(define mvector-result (make-mvector mdevice 'float vector-size))


(compute-add mdevice mlibrary mvector-A mvector-B mvector-result)

(define results (mvector->cvector mvector-result))




(define mvector-C (create-mvector mdevice (list->cvector (list 1.0 2.0 3.0 4.0) _float) 
                                  'METAL_FLOAT 
                                  4))

;(ptr-ref mvector-C _metal_data_type 1)
(println (metal_vector->data_type mvector-C))




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
