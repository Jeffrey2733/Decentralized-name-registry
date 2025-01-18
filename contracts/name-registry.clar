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
