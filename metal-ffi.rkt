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
           METAL_MUL = 1
           METAL_MAT_ADD = 2
           METAL_MAT_MUL = 3)
         _uint32
         #:unknown (lambda (x)
                     (cond [(eq? x 'METAL_ADD) 0]
                           [(eq? x 'METAL_MUL) 1]
                           [(eq? x 'METAL_MAT_ADD) 2]
                           [(eq? x 'METAL_MAT_MUL) 3]
                           [else (error 'metal_operation "unknown enum value")]))))


(define-cstruct _metal_config
  ([device        _pointer]
   [library       _pointer]))

(define (metal_config->device metal-config)
  (ptr-ref metal-config _pointer 0))
(define (metal_config->library metal-config)
  (ptr-ref metal-config _pointer 1))



#| Initialization functions |#
(define-metal create-metal-device
  (_fun _string -> _pointer)
  #:c-id createMetalDevice)

(define-metal initialize-metal
  (_fun _string -> _metal_config)
  #:c-id initializeMetal)


(define-metal create-metal-library
  (_fun _pointer _string -> _pointer)
  #:c-id createMetalLibrary)




#| Vector
   All stuff vector related.
|#
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

(define (compute-mul-with-allocated-result metal-config mvector-A mvector-B mvector-Result)
  (let ([result (compute-with-allocated-result-ffi metal-config mvector-A mvector-B mvector-Result 'METAL_MUL)])
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

(define (compute-mul metal-config mvector-A mvector-B)
  (let ([result (compute-ffi metal-config mvector-A mvector-B 'METAL_MUL)])
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
           [_ (error "Unexpected data-type in mvector->cvector definiton.")])])
    (let ([vec-len (metal_vector->data_len m-vector)])
      (make-cvector* (float-mvector->cvector-ffi m-vector) type vec-len))))

(define (mvector->list m-vector)
  (cvector->list (mvector->cvector m-vector)))


(define (list->mvector metal-config lst #:data-type [data-type 'METAL_FLOAT])
  (match data-type
    ['METAL_FLOAT (cvector->mvector metal-config (list->cvector lst _float))]
    ['METAL_INT32 (cvector->mvector metal-config (list->cvector lst _int32))]
    [_ (error "Unexpected data-type in list->mvector definiton.")]))


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









#| Matrix
   All stuff matrix related.
|#
(define-cstruct _metal_matrix
  ([data_ptr                      _pointer] ; id<MTLBuffer> 8 bytes
   [data_len                      _size] ; 8 bytes
   [data_rows                     _size] ; 8 bytes
   [data_cols                     _size] ; 8 bytes
   [data_rows_ptr                 _pointer] ; id<MTLBuffer> 8 bytes
   [data_cols_ptr                 _pointer] ; id<MTLBuffer> 8 bytes
   [data_type                     _metal_data_type #:offset 12] ; enum 4 bytes
   [metal_config                  _metal_config]) ; metal_config 16 bytes
  #:alignment 8)

(define (display-mmatrix m-matrix [name "unnamed"])
  (printf "\n____________________\nMatrix [~a]:\n  data_ptr: ~a\n  data_len: ~a\n  data_rows: ~a\n  data_cols: ~a\n  data_rows_ptr: ~a\n  data_cols_ptr: ~a\n  data_type: ~a\n  metal_config: ~a\n____________________\n"
          name
          (metal_matrix-data_ptr m-matrix)
          (metal_matrix-data_len m-matrix)
          (metal_matrix-data_rows m-matrix)
          (metal_matrix-data_cols m-matrix)
          (metal_matrix-data_rows_ptr m-matrix)
          (metal_matrix-data_cols_ptr m-matrix)
          (metal_matrix-data_type m-matrix)
          (metal_matrix-metal_config m-matrix)))



(define (mmatrix->ptr m-matrix)
  (metal_matrix-data_ptr m-matrix))
(define (mmatrix->length m-matrix)
  (metal_matrix-data_len m-matrix))




;; Compute functions
(define-metal compute-mat-ffi
  (_fun _pointer
        _pointer
        _pointer
        _metal_operation
        -> _metal_matrix)
  #:c-id computeMatrix)

(define (compute-mat-add metal-config mmatrix-A mmatrix-B)
  (let ([result (compute-mat-ffi metal-config mmatrix-A mmatrix-B 'METAL_MAT_ADD)])
    (if (not result)
        (error "compute returned error.")
        result)))

(define (compute-mat-mul metal-config mmatrix-A mmatrix-B)
  (let ([result (compute-mat-ffi metal-config mmatrix-A mmatrix-B 'METAL_MAT_MUL)])
    (if (not result)
        (error "compute returned error.")
        result)))




;; Create matrix
(define-metal float-mmatrix->cvector-ffi
  (_fun _metal_matrix
        -> _pointer)
  #:c-id getCFloatMatrix)

(define-metal int32-mmatrix->cvector-ffi
  (_fun _metal_matrix
        -> _pointer)
  #:c-id getCInt32Matrix)


(define (list->2d-list lst cols)
  (define (part lst)
    (cond
      [(empty? lst) '()]
      [else (cons (take lst cols) (part (drop lst cols)))]))
  (if (not (equal? 0 (remainder (length lst) cols)))
      (error "Tried to make 2d list from 1d, but dimensions are not correct")
      (part lst)))




(define (mmatrix->list m-matrix)
  (let ([dtype (metal_matrix-data_type m-matrix)])
    (let ([data_type (match dtype
                       ['METAL_FLOAT _float]
                       ['METAL_INT32 _int32]
                       [_ (error (format "type ~a not supported" dtype))])]
          [cols (metal_matrix-data_cols m-matrix)]
          [data_length (metal_matrix-data_len m-matrix)])
      (list->2d-list
       (cvector->list 
        (make-cvector* ((match dtype
                          ['METAL_FLOAT float-mmatrix->cvector-ffi]
                          ['METAL_INT32 int32-mmatrix->cvector-ffi]
                          [_ (error "Unsupported m-type")])
                        m-matrix) data_type data_length)) cols))))


(define (cvector->mmatrix metal-config c-vector cols)
  (let ([data-type (match (ctype->layout (cvector-type c-vector))
                     ['float 'METAL_FLOAT]
                     ['int32 'METAL_INT32]
                     [_ (error
                         (format "Unsupported cvector type \"~a\" in cvector->mmatrix definiton. Have to be one of: 'float 'int32"
                                 (ctype->layout (cvector-type c-vector))))])]
        [c-vec-length (cvector-length c-vector)])
    (if (not (equal? 0 (remainder c-vec-length cols)))
        (error (format "Cannot transform cvector of length ~a into vector with col len of ~a" c-vec-length cols))
        (create-mmatrix metal-config
                        c-vector
                        (/ c-vec-length cols)
                        cols
                        data-type))))



(define (list->mmatrix metal-config lst #:data-type [data-type 'METAL_FLOAT])
  (cond
    [(not (list? lst)) (error "Provided lst argument is not a list.")]
    [(null? lst) #f] ; we dont' crash, but we return "None"
    [(not (list? (car lst))) (error "Matrix is expected to be list of lists, but first element is not.")]
    [(let ([sublist-len (length (car lst))])
       (foldl (lambda (sublist acc) (or acc 
                                        (not (list? sublist))
                                        (not (equal? sublist-len (length sublist)))))
              #f 
              lst))
     (error "Matrix is expected to be list of equal sized lists, but it isn't.")]
    [else (let ([cols (length (car lst))])
            (match data-type
              ['METAL_FLOAT (cvector->mmatrix metal-config (list->cvector (map exact->inexact (flatten lst)) _float) cols)]
              ['METAL_INT32 (cvector->mmatrix metal-config (list->cvector (map inexact->exact (flatten lst)) _int32) cols)]
              [_ (error "Unexpected data-type in list->mvector definiton")]))]))





(define-metal create-mmatrix
  (_fun _pointer ; metal_config
        [vec : _cvector]
        [_int = (cvector-length vec)]
        _size ; rows
        _size ; cols
        _metal_data_type   ; type
        -> _metal_matrix)
  #:c-id createMetalMatrix)






