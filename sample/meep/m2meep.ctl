; MEEP sim to demonstrate m2pvpk_meep
;
;

(define-param qresol  4);
(define-param worldsize   10);
(define-param blocksize   (/ worldsize 3))
(define-param eps00       2.00)


; ----------------------------------------------------------------------


(define (fmedium p)
  (make dielectric 
    (epsilon 
      (epsvariation p)
    )
  )
)


(set! geometry 
  (list 
    (make block
      (center 0 0 0) 
      (size blocksize blocksize blocksize)
      (material 
        (make dielectric (epsilon eps00))
      )
    )
  )
)

(set! geometry-lattice (make lattice (size worldsize worldsize worldsize)))

  (set! sources (append sources 
    (list
      (make source
        (src (make gaussian-src
              (frequency 1.00)
              (width 5)
              (start-time  1)
             )
        )
        (amplitude 1.00)
        (component Ey) 
        (center  0.00 0.00 0.00)
      )
    )
  ))


(set! resolution qresol)
(set! pml-layers (list (make pml (thickness 1.0) (direction X) )))

(define-param tinterval 0.20)

(run-until 50
    (at-beginning 
        output-epsilon
    )
    ;(after-sources
        (at-every tinterval output-efield-x)
        (at-every tinterval output-efield-y)
        (at-every tinterval output-efield-z)
        ;(at-end)
    ;)
)

