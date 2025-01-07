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


(define _float_ptr
  (_cpointer _float))


(define _metal_data_type
  (_enum '(METAL_FLOAT = 0
           METAL_INT32 = 1)
         _uint32
         #:unknown (lambda (x)
                     (cond [(eq? x 'METAL_FLOAT)  0]
                           [(eq? x 'METAL_INT32) 1]
                           [else (error 'metal_data_type "unknown enum value")]))))


(define-cstruct _metal_config
                ([device        _pointer]
                 [library       _pointer]))

(define (metal_config->device metal-config)
  (ptr-ref metal-config _pointer 0))
(define (metal_config->library metal-config)
  (ptr-ref metal-config _pointer 1))

(define-cstruct _metal_vector
                ([data_ptr         _pointer]
                 [data_len         _size]
                 [data_type        _metal_data_type]
                 [metal_config     _metal_config]))

(define (metal_vector->data_ptr metal-vector)
  (ptr-ref metal-vector _pointer 0))
(define (metal_vector->data_len metal-vector)
  (ptr-ref metal-vector _size 1))
(define (metal_vector->data_type metal-vector)
  (ptr-ref metal-vector _metal_data_type 2))
(define (metal_vector->device metal-vector)
  (ptr-ref metal-vector _pointer 3))

(define (mvector->ptr m-vector)
  (metal_vector->data_ptr m-vector))
(define (mvector->length m-vector)
  (metal_vector->data_len m-vector))






(define-metal create-metal-device
  (_fun _string -> _pointer)
  #:c-id createMetalDevice)

(define-metal initialize-metal
  (_fun _string -> _metal_config)
  #:c-id initializeMetal)


(define-metal create-metal-library
  (_fun _pointer _string -> _pointer)
  #:c-id createMetalLibrary)





(define-metal compute-add-with-allocated-result-ffi
  (_fun _pointer
        _pointer
        _pointer
        _pointer
        -> _bool)
  #:c-id computeAddWithAllocatedResultBuffer)

(define (compute-add-with-allocated-result metal-config mvector-A mvector-B mvector-Result)
  (let ([result (compute-add-with-allocated-result-ffi metal-config mvector-A mvector-B mvector-Result)])
    (if (not result)
        (error "ComputeAdd returned error.")
        result)))


(define-metal compute-add-ffi
  (_fun _pointer
        _pointer
        _pointer
        -> _metal_vector)
  #:c-id computeAdd)

(define (compute-add metal-config mvector-A mvector-B)
  (let ([result (compute-add-ffi metal-config mvector-A mvector-B)])
    (if (not result)
        (error "ComputeAdd returned error.")
        result)))






(define-metal mvector->cvector-ffi
  (_fun _metal_vector
        -> _pointer)
  #:c-id getCVector)

(define (mvector->cvector m-vector)
  (let ([vec-len (metal_vector->data_len m-vector)])
        (make-cvector* (mvector->cvector-ffi m-vector) _float vec-len)))

(define (mvector->list m-vector)
  (cvector->list (mvector->cvector m-vector)))


(define (list->mvector metal-config lst #:data-type [data-type 'METAL_FLOAT])
  (match data-type
    ['METAL_FLOAT 
     (create-mvector metal-config 
                (list->cvector lst _float) 
                                  'METAL_FLOAT 
                                  (length lst))]
    ['METAL_INT32
     (create-mvector metal-config 
                (list->cvector lst _int32) 
                                  'METAL_INT32 
                                  (length lst))]
    [_ (error "Unexpected data-type in list->mvector definiiton")]))





(define-metal create-mvector
  (_fun _pointer ; metal_config
        [vec : _cvector]
        [_int = (cvector-length vec)]
        _metal_data_type   ; type
        _int32   ; length
        -> _metal_vector)
  #:c-id createMetalVector)

(define-metal destroy-mvector
#| DON'T USE IT. It doesn't really work |#
              (_fun _metal_vector
                    -> _void)
  #:c-id destroyMetalVector)









;; functional API

(define metal-config (initialize-metal metallib-path))




;; With result buffer preallocation

(define mvector-A (list->mvector metal-config 
                                 (list 1.0 2.0 3.0 4.0)))
(define mvector-B (list->mvector metal-config 
                                 (list 1.0 2.0 3.0 4.0)))
(define mvector-r1 (list->mvector metal-config 
                                  (make-list 4 0.0)))

(void (compute-add-with-allocated-result metal-config mvector-A mvector-B mvector-r1))

(define r1 (mvector->list mvector-r1))

(printf "Results:  ~a\n" r1)





;; Without prealocation


(define mvector-C (list->mvector metal-config 
                                 (list 1.0 2.0 3.0 4.0)))
(define mvector-D (list->mvector metal-config 
                                 (list 1.0 2.0 3.0 4.0)))
(define mvector-r2 (compute-add metal-config mvector-C mvector-D))

(define r2 (mvector->list mvector-r2))

(printf "Results:  ~a\n" r2)


