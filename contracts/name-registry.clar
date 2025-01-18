(define-map names-map (string-ascii 50) principal)

(define-public (claim-name (name (string-ascii 50)))
    (if (is-some (map-get? names-map name))
        (err u100)
        (begin
          (map-set names-map name tx-sender)
          (ok true)
        )
    )
)

(define-read-only (get-owner (name (string-ascii 50)))
  (map-get? names-map name)
)


;; Add at the top
(define-map name-expiry (string-ascii 50) uint)
(define-constant REGISTRATION_PERIOD u31536000) ;; 1 year in seconds

(define-public (claim-name-with-expiry (name (string-ascii 50)))
    (let ((current-time block-height))
        (if (is-some (map-get? names-map name))
            (err u100)
            (begin
                (map-set names-map name tx-sender)
                (map-set name-expiry name (+ current-time REGISTRATION_PERIOD))
                (ok true)
            )
        )
    )
)
