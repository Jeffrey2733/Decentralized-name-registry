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



(define-public (transfer-name (name (string-ascii 50)) (new-owner principal))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set names-map name new-owner)
                (ok true)
            )
            (err u101)
        )
    )
)


(define-public (release-name (name (string-ascii 50)))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-delete names-map name)
                (ok true)
            )
            (err u102)
        )
    )
)



(define-constant REGISTRATION_FEE u100000) ;; in microSTX
(define-constant CONTRACT_OWNER tx-sender)

(define-public (claim-name-with-fee (name (string-ascii 50)))
    (if (is-some (map-get? names-map name))
        (err u100)
        (begin
            (try! (stx-transfer? REGISTRATION_FEE tx-sender CONTRACT_OWNER))
            (map-set names-map name tx-sender)
            (ok true)
        )
    )
)


(define-constant MIN_LENGTH u3)
(define-constant MAX_LENGTH u50)

(define-private (is-valid-length (name (string-ascii 50)))
    (let ((name-length (len name)))
        (and (>= name-length MIN_LENGTH) (<= name-length MAX_LENGTH))
    )
)

(define-public (claim-validated-name (name (string-ascii 50)))
    (if (not (is-valid-length name))
        (err u103)
        (claim-name name)
    )
)



(define-map name-data 
    (string-ascii 50) 
    {
        website: (optional (string-ascii 100)),
        description: (optional (string-ascii 200))
    }
)

(define-public (set-name-data (name (string-ascii 50)) (website (optional (string-ascii 100))) (description (optional (string-ascii 200))))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set name-data name {website: website, description: description})
                (ok true)
            )
            (err u104)
        )
    )
)


(define-map name-index uint (string-ascii 50))
(define-data-var name-counter uint u0)

(define-public (register-indexed-name (name (string-ascii 50)))
    (let ((counter (var-get name-counter)))
        (if (is-some (map-get? names-map name))
            (err u100)
            (begin
                (map-set names-map name tx-sender)
                (map-set name-index counter name)
                (var-set name-counter (+ counter u1))
                (ok true)
            )
        )
    )
)

(define-read-only (get-name-by-index (index uint))
    (map-get? name-index index)
)



