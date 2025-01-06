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


(define-cstruct _metal_vector
                ([buffer_ptr    _pointer]
                 [buffer_len    _size]
                 [data_type     _metal_data_type]
                 [device        _pointer]))

(define (metal_vector->buffer_ptr metal-vector)
  (ptr-ref metal-vector _pointer 0))
(define (metal_vector->buffer_len metal-vector)
  (ptr-ref metal-vector _size 1))
(define (metal_vector->data_type metal-vector)
  (ptr-ref metal-vector _metal_data_type 2))
(define (metal_vector->device metal-vector)
  (ptr-ref metal-vector _pointer 3))

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



;computeAddWithAllocatedResultBuffer


(define-metal compute-add-with-allocated-result-orig
  (_fun _pointer
        _pointer
        _pointer
        _pointer
        _pointer
        -> _bool)
  #:c-id computeAddWithAllocatedResultBuffer)

(define (compute-add-with-allocated-result mdevice mlibrary mvector-A mvector-B mvector-Result)
  (let ([result (compute-add-with-allocated-result-orig mdevice mlibrary mvector-A mvector-B mvector-Result)])
    (if (not result)
        (error "ComputeAdd returned error.")
        result)))


(define-metal compute-add-orig
  (_fun _pointer
        _pointer
        _pointer
        _pointer
        -> _metal_vector)
  #:c-id computeAdd)

(define (compute-add mdevice mlibrary mvector-A mvector-B)
  (let ([result (compute-add-orig mdevice mlibrary mvector-A mvector-B)])
    (if (not result)
        (error "ComputeAdd returned error.")
        result)))






(define-metal mvector->cvector-orig
  (_fun _metal_vector
        -> _float_ptr)
  #:c-id getCVector)

(define (mvector->cvector vec)
  (values (mvector->cvector-orig vec) (metal_vector->buffer_len vec)))









(define-metal create-mvector
  (_fun _pointer ; device
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
(define mdevice (create-metal-device metallib-path))
(define mlibrary (create-metal-library mdevice metallib-path))


(define vector-size (expt 2 24))

;; (define cvector-A (list->cvector 
;;                     (make-list vector-size 1.0)
;;                     _float))
;; (define mvector-A (cvector->mvector mdevice cvector-A))

;; (define cvector-B (list->cvector 
;;                     (make-list vector-size 2.0) 
;;                     _float))
;; (define mvector-B (cvector->mvector mdevice cvector-B))

;; (define mvector-result (make-mvector mdevice 'float vector-size))


;; (compute-add-obsolete mdevice mlibrary mvector-A mvector-B mvector-result)

;; (define results (mvector->cvector mvector-result))

;; (let ([n 10])
;;   (displayln
;;  (format "First ~a thingies:  ~a"
;;          n
;;          (map (λ (i)
;;                 (ptr-ref results _float i))
;;               (range n))
;;          )))





(define mvector-C (create-mvector mdevice (list->cvector (list 1.0 2.0 3.0 4.0) _float) 
                                  'METAL_FLOAT 
                                  4))
(define mvector-D (create-mvector mdevice (list->cvector (list 1.0 2.0 3.0 4.0) _float) 
                                  'METAL_FLOAT 
                                  4))

;; (define mvector-r (create-mvector mdevice (list->cvector (list 0.0 0.0 0.0 0.0) _float) 
;;                                   'METAL_FLOAT 
;;                                   4))


(define mvector-r (compute-add mdevice mlibrary mvector-C mvector-D))


(define-values (cvector-r r-len) (mvector->cvector mvector-r))

(let ([n r-len])
  (displayln
 (format "First ~a thingies:  ~a"
         n
         (map (λ (i)
                (ptr-ref cvector-r _float i))
              (range n))
         )))



;; (perform-computation-with-inputs adder dataA dataB)

(struct Tensor (weights bias forward)
  #:transparent)

;(define tensor (Tensor weights bias (λ (X) (plus (times weights X) bias))))
