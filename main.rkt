#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         ffi/cvector
         ffi/unsafe/cvector)
(provide (all-defined-out))

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
                     (cond [(eq? x 'METAL_FLOAT) 0]
                           [(eq? x 'METAL_INT32) 1]
                           [else (error 'metal_data_type "unknown enum value")]))))


(define _metal_operation
  (_enum '(METAL_ADD = 0
           METAL_MULT = 1)
         _uint32
         #:unknown (lambda (x)
                     (cond [(eq? x 'METAL_ADD) 0]
                           [(eq? x 'METAL_MULT) 1]
                           [else (error 'metal_operation "unknown enum value")]))))


(define-cstruct _metal_config
                ([device        _pointer]
                 [library       _pointer]))

(define (metal_config->device metal-config)
  (ptr-ref metal-config _pointer 0))
(define (metal_config->library metal-config)
  (ptr-ref metal-config _pointer 1))

(define-cstruct _metal_vector
                ([data_ptr                      _pointer]
                 [data_len                      _size]
                 [this-is-artifact-skip-it      _size]
                 [data_type                     _metal_data_type]
                 [metal_config                  _metal_config]))

(define (metal_vector->data_ptr metal-vector)
  (ptr-ref metal-vector _pointer 0))
(define (metal_vector->data_len metal-vector)
  (ptr-ref metal-vector _size 1))
(define (metal_vector->data_type metal-vector)
  (ptr-ref metal-vector _metal_data_type 3))
(define (metal_vector->device metal-vector)
  (ptr-ref metal-vector _pointer 4))

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





(define-metal compute-with-allocated-result-ffi
  (_fun _pointer
        _pointer
        _pointer
        _pointer
        _metal_operation
        -> _bool)
  #:c-id computeWithAllocatedResultBuffer)

(define (compute-add-with-allocated-result metal-config mvector-A mvector-B mvector-Result)
  (let ([result (compute-with-allocated-result-ffi metal-config mvector-A mvector-B mvector-Result 'METAL_ADD)])
    (if (not result)
        (error "compute returned error.")
        result)))

(define (compute-mult-with-allocated-result metal-config mvector-A mvector-B mvector-Result)
  (let ([result (compute-with-allocated-result-ffi metal-config mvector-A mvector-B mvector-Result 'METAL_MULT)])
    (if (not result)
        (error "compute returned error.")
        result)))





(define-metal compute-ffi
  (_fun _pointer
        _pointer
        _pointer
        _metal_operation
        -> _metal_vector)
  #:c-id compute)

(define (compute-add metal-config mvector-A mvector-B)
  (let ([result (compute-ffi metal-config mvector-A mvector-B 'METAL_ADD)])
    (if (not result)
        (error "compute returned error.")
        result)))

(define (compute-mult metal-config mvector-A mvector-B)
  (let ([result (compute-ffi metal-config mvector-A mvector-B 'METAL_MULT)])
    (if (not result)
        (error "compute returned error.")
        result)))





(define-metal float-mvector->cvector-ffi
  (_fun _metal_vector
        -> _pointer)
  #:c-id getCFloatVector)

(define-metal int32-mvector->cvector-ffi
  (_fun _metal_vector
        -> _pointer)
  #:c-id getCInt32Vector)


(define (mvector->cvector m-vector)
  (let ([type  
         (match (metal_vector->data_type m-vector)
           ['METAL_FLOAT _float]
           ['METAL_INT32 _int32]
           [_ (error "Unexpected data-type in mvector->cvector definiiton")])])
    (let ([vec-len (metal_vector->data_len m-vector)])
      (make-cvector* (float-mvector->cvector-ffi m-vector) type vec-len))))

(define (mvector->list m-vector)
  (cvector->list (mvector->cvector m-vector)))


(define (list->mvector metal-config lst #:data-type [data-type 'METAL_FLOAT])
  (match data-type
    ['METAL_FLOAT (cvector->mvector metal-config (list->cvector lst _float))]
    ['METAL_INT32 (cvector->mvector metal-config (list->cvector lst _int32))]
    [_ (error "Unexpected data-type in list->mvector definiton")]))


(define (cvector->mvector metal-config c-vector)
  (let ([data-type (match (ctype->layout (cvector-type c-vector))
                     ['float 'METAL_FLOAT]
                     ['int32 'METAL_INT32]
                     [_ (error
                         (format "Unsupported cvector type \"~a\" in cvector->mvector definiton. Have to be one of: 'float 'int32"
                                 (ctype->layout (cvector-type c-vector))))])]
        [c-vec-length (cvector-length c-vector)])
    (create-mvector metal-config 
                    c-vector
                    data-type
                    c-vec-length)))


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



;; Test cvector->mvector back and forth
(let ([metal-config (initialize-metal metallib-path)])
  (mvector->list (cvector->mvector metal-config
                                   (mvector->cvector (list->mvector metal-config 
                                                                    (list 1.0 2.0 3.0 4.0))))))

;; Test list->mvector back and forth
(let ([metal-config (initialize-metal metallib-path)])
  (mvector->list (create-mvector metal-config
                                 (mvector->cvector (list->mvector metal-config 
                                                                  (list 1.0 2.0 3.0 4.0)))
                                 'METAL_FLOAT
                                 4)))




;; With result buffer preallocation
(let ([metal-config (initialize-metal metallib-path)])
  (define mvector-A (list->mvector metal-config 
                                   (list 1.0 2.0 3.0 4.0)))
  (define mvector-B (list->mvector metal-config 
                                   (list 1.0 2.0 3.0 4.0)))


  (define mvector-r1 (list->mvector metal-config 
                                    (make-list 4 0.0)))
  (void (compute-add-with-allocated-result metal-config mvector-A mvector-B mvector-r1))


  (define r1 (mvector->list mvector-r1))
  (printf "Results:  ~a\n" r1))





;; Without prealocation

(let ([metal-config (initialize-metal metallib-path)])
  (define mvector-C (list->mvector metal-config 
                                   (list 1.0 2.0 3.0 4.0)))
  (define mvector-D (list->mvector metal-config 
                                   (list 1.0 2.0 3.0 4.0)))


  (define mvector-r2 (compute-mult metal-config mvector-C mvector-D))


  (define r2 (mvector->list mvector-r2))
  (printf "Results:  ~a\n" r2))

