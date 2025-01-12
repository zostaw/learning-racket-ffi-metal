#lang racket

(require ffi/unsafe
         ffi/unsafe/define
         ffi/cvector
         ffi/unsafe/cvector)
(require "metal-ffi.rkt")



  ;; With result buffer preallocation
  (let ([metal-config (initialize-metal metallib-path)])
    (printf "###### Metal Vectors computation - with result buffer preallocation ######\n")
    (define list-A (list 1.0 2.0 3.0 4.0))
    (define list-B (list 1.0 2.0 3.0 4.0))
    (printf "list A: ~a\nlist B: ~a\n" list-A list-B)

    (define mvector-A (list->mvector metal-config list-A))
    (define mvector-B (list->mvector metal-config list-B))
  
    (define mvector-r1 (list->mvector metal-config (make-list 4 0.0)))

    (void (compute-add-with-allocated-result metal-config mvector-A mvector-B mvector-r1))
  
    (define r1 (mvector->list mvector-r1))
    (printf "###### Result A+B: ~a ######\n\n\n\n" r1))




  ;; Without prealocation
  (let ([metal-config (initialize-metal metallib-path)])
    (printf "###### Metal Vectors computation - without result buffer preallocation ######\n")
    (define list-C (list 1.0 2.0 3.0 4.0))
    (define list-D (list 1.0 2.0 3.0 4.0))
    (printf "list C: ~a\nlist D: ~a\n" list-C list-D)

    (define mvector-C (list->mvector metal-config
                                     (list 1.0 2.0 3.0 4.0)))
    (define mvector-D (list->mvector metal-config 
                                     (list 1.0 2.0 3.0 4.0)))

    (define mvector-r2 (compute-mul metal-config mvector-C mvector-D))

    (define r2 (mvector->list mvector-r2))
    (printf "###### Result C+D: ~a ######\n\n\n\n" r2))







#| Compute mat-add  |#
  (let ([metal-config (initialize-metal metallib-path)])
    (printf "###### Metal Matrices - ADD ######\n")

    (define list-A '((1 2 3 4)
                     (4 5 6 4)
                     (7 8 9 4)))
    (define list-B '((1 2 3 4)
                     (4 5 6 4)
                     (7 8 9 4)))
    (printf "list A: ~a\nlist B: ~a\n" list-A list-B)

    (define A (list->mmatrix metal-config list-A))
    (define B (list->mmatrix metal-config list-B))


    (define C (compute-mat-add metal-config A B))
    (define C-list (mmatrix->list C))

    (printf "###### Result C+D: ~a ######\n\n\n\n" C-list))




#| Compute matmul  |#
  (let ([metal-config (initialize-metal metallib-path)])
    (printf "###### Metal Matrices - matmul ######\n")

    (define list-A '((1 2 3 4)
                     (4 5 6 4)
                     (7 8 9 4)))
    (define list-B '((1 2 3 4)
                     (4 5 6 4)
                     (7 8 9 4)))
    (printf "list A: ~a\nlist B: ~a" list-A list-B)

    (define A (list->mmatrix metal-config '((1 2 3 4) 
                                            (4 5 6 4)
                                            (7 8 9 4))))
    (define B (list->mmatrix metal-config '((1 2 3 4 5)
                                            (4 5 6 4 5)
                                            (4.5 5.5 6.5 4.5 5.5)
                                            (7 8 9 4 8))))
    (display-mmatrix A "Matrix A struct")
    (display-mmatrix B "Matrix B struct")

    (define C (compute-mat-mul metal-config A B))
    (define C-list (mmatrix->list C))

    (printf "###### Result matmul(C, D): ~a ######\n\n\n\n" C-list))
