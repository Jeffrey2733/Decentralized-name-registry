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



(define-map name-search-index (string-ascii 50) bool)

(define-public (search-name (query (string-ascii 50)))
    (ok (is-some (map-get? names-map query)))
)



(define-constant PREMIUM_FEE u500000)
(define-map premium-names (string-ascii 50) bool)

(define-public (register-premium-name (name (string-ascii 50)))
    (if (is-some (map-get? names-map name))
        (err u100)
        (begin
            (try! (stx-transfer? PREMIUM_FEE tx-sender CONTRACT_OWNER))
            (map-set premium-names name true)
            (map-set names-map name tx-sender)
            (ok true)
        )
    )
)



(define-constant RENEWAL_FEE u50000)

(define-public (renew-name (name (string-ascii 50)))
    (let ((current-owner (get-owner name))
          (current-time block-height))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set name-expiry name (+ current-time REGISTRATION_PERIOD))
                (try! (stx-transfer? RENEWAL_FEE tx-sender CONTRACT_OWNER))
                (ok true)
            )
            (err u105)
        )
    )
)


(define-map subdomains 
    {parent: (string-ascii 50), subdomain: (string-ascii 20)} 
    principal)

(define-public (register-subdomain (parent (string-ascii 50)) (subdomain (string-ascii 20)))
    (let ((parent-owner (get-owner parent)))
        (if (and (is-some parent-owner) (is-eq (some tx-sender) parent-owner))
            (begin
                (map-set subdomains {parent: parent, subdomain: subdomain} tx-sender)
                (ok true)
            )
            (err u106)
        )
    )
)



(define-map name-sales 
    (string-ascii 50) 
    {price: uint, seller: principal})

(define-public (list-name-for-sale (name (string-ascii 50)) (price uint))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set name-sales name {price: price, seller: tx-sender})
                (ok true)
            )
            (err u107)
        )
    )
)

(define-public (buy-listed-name (name (string-ascii 50)))
    (let ((sale (map-get? name-sales name)))
        (match sale
            sale-data (begin
                (try! (stx-transfer? (get price sale-data) tx-sender (get seller sale-data)))
                (map-set names-map name tx-sender)
                (map-delete name-sales name)
                (ok true)
            )
            (err u108)
        )
    )
)



(define-map blacklisted-names (string-ascii 50) bool)
(define-constant CONTRACT_ADMIN tx-sender)

(define-public (blacklist-name (name (string-ascii 50)))
    (if (is-eq tx-sender CONTRACT_ADMIN)
        (begin
            (map-set blacklisted-names name true)
            (ok true)
        )
        (err u110)
    )
)



(define-map name-stats
    (string-ascii 50)
    {registration-time: uint,
     transfer-count: uint,
     last-transfer: uint})

(define-public (update-name-stats (name (string-ascii 50)))
    (let ((current-stats (map-get? name-stats name))
          (current-time block-height))
        (match current-stats
            stats (map-set name-stats name 
                {registration-time: (get registration-time stats),
                 transfer-count: (+ (get transfer-count stats) u1),
                 last-transfer: current-time})
            (map-set name-stats name 
                {registration-time: current-time,
                 transfer-count: u0,
                 last-transfer: current-time})
        )
        (ok true)
    )
)
(define-public (batch-register-names (names (list 10 (string-ascii 50))))
    (fold check-and-register names (ok true))
)

(define-private (check-and-register (name (string-ascii 50)) (previous-result (response bool uint)))
    (if (is-ok previous-result)
        (claim-name name)
        previous-result
    )
)


(define-map name-watchlist 
    {user: principal, name: (string-ascii 50)} 
    {watch-date: uint})

(define-public (watch-name (name (string-ascii 50)))
    (begin
        (map-set name-watchlist 
            {user: tx-sender, name: name}
            {watch-date: block-height}
        )
        (ok true)
    )
)


(define-map name-ratings
    {name: (string-ascii 50), rater: principal}
    {rating: uint, timestamp: uint})

(define-public (rate-name (name (string-ascii 50)) (rating uint))
    (if (and (>= rating u1) (<= rating u5))
        (begin
            (map-set name-ratings
                {name: name, rater: tx-sender}
                {rating: rating, timestamp: block-height}
            )
            (ok true)
        )
        (err u111)
    )
)

(define-map name-categories
    (string-ascii 50)
    (string-ascii 8))

(define-constant VALID-CATEGORIES (list "personal" "business" "gaming" "social"))

(define-public (set-name-category (name (string-ascii 50)) (category (string-ascii 8)))
    (let ((current-owner (get-owner name)))
        (if (and 
            (is-some current-owner)
            (is-eq (some tx-sender) current-owner)
            (is-some (index-of VALID-CATEGORIES category))
        )
            (begin
                (map-set name-categories name category)
                (ok true)
            )
            (err u112)
        )
    )
)


(define-map referrals
    (string-ascii 50)
    {referrer: principal, reward: uint})

(define-constant REFERRAL_REWARD u10000)

(define-public (register-with-referral (name (string-ascii 50)) (referrer principal))
    (begin
        (try! (claim-name name))
        (try! (stx-transfer? REFERRAL_REWARD CONTRACT_OWNER referrer))
        (map-set referrals name {referrer: referrer, reward: REFERRAL_REWARD})
        (ok true)
    )
)


(define-map name-bundles
    (string-ascii 50)
    {names: (list 10 (string-ascii 50)), price: uint, owner: principal})

(define-public (create-name-bundle (bundle-id (string-ascii 50)) (names (list 10 (string-ascii 50))) (price uint))
    (begin
        (map-set name-bundles bundle-id
            {names: names, price: price, owner: tx-sender}
        )
        (ok true)
    )
)


(define-map name-auctions
    (string-ascii 50)
    {
        highest-bid: uint,
        highest-bidder: principal,
        end-block: uint
    })

(define-public (start-auction (name (string-ascii 50)) (duration uint))
    (if (is-none (map-get? names-map name))
        (begin
            (map-set name-auctions name
                {
                    highest-bid: u0,
                    highest-bidder: tx-sender,
                    end-block: (+ block-height duration)
                }
            )
            (ok true)
        )
        (err u113)
    )
)

(define-public (place-bid (name (string-ascii 50)) (bid uint))
    (let ((auction (map-get? name-auctions name)))
        (match auction
            auction-data (if (> bid (get highest-bid auction-data))
                (begin
                    (try! (stx-transfer? bid tx-sender CONTRACT_OWNER))
                    (map-set name-auctions name
                        {
                            highest-bid: bid,
                            highest-bidder: tx-sender,
                            end-block: (get end-block auction-data)
                        }
                    )
                    (ok true)
                )
                (err u114))
            (err u115)
        )
    )
)


(define-public (end-auction (name (string-ascii 50)))
    (let ((auction (map-get? name-auctions name)))
        (match auction
            auction-data (begin
                (try! (stx-transfer? (get highest-bid auction-data) CONTRACT_OWNER (get highest-bidder auction-data)))
                (map-set names-map name (get highest-bidder auction-data))
                (map-delete name-auctions name)
                (ok true)
            )
            (err u116)
        )
    )
)




(define-map verified-names (string-ascii 50) bool)
(define-constant VERIFICATION_FEE u200000)

(define-public (verify-name (name (string-ascii 50)))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (try! (stx-transfer? VERIFICATION_FEE tx-sender CONTRACT_OWNER))
                (map-set verified-names name true)
                (ok true)
            )
            (err u120)
        )
    )
)


(define-map name-history
    (string-ascii 50)
    (list 10 {owner: principal, timestamp: uint}))

(define-public (record-transfer (name (string-ascii 50)) (new-owner principal))
    (let ((history (map-get? name-history name)))
        (map-set name-history name
            (unwrap-panic (as-max-len? 
                (append (default-to (list) history)
                    {owner: new-owner, timestamp: block-height})
                u10)))
        (ok true)
    )
)


(define-constant RESERVATION_PERIOD u1000)
(define-map reserved-names 
    (string-ascii 50) 
    {reserver: principal, expiry: uint})

(define-public (reserve-name (name (string-ascii 50)))
    (if (is-some (map-get? names-map name))
        (err u130)
        (begin
            (map-set reserved-names name 
                {reserver: tx-sender, 
                 expiry: (+ block-height RESERVATION_PERIOD)})
            (ok true)
        )
    )
)


(define-map name-groups 
    (string-ascii 50)
    (list 20 (string-ascii 50)))

(define-public (create-name-group (group-name (string-ascii 50)) (names (list 20 (string-ascii 50))))
    (let ((owner-check (get-owner group-name)))
        (if (is-eq (some tx-sender) owner-check)
            (begin
                (map-set name-groups group-name names)
                (ok true)
            )
            (err u140)
        )
    )
)


(define-map trading-volume
    (string-ascii 50)
    {total-volume: uint, last-price: uint})

(define-public (record-trade (name (string-ascii 50)) (price uint))
    (let ((volume-data (map-get? trading-volume name)))
        (match volume-data
            data (map-set trading-volume name
                {total-volume: (+ (get total-volume data) price),
                 last-price: price})
            (map-set trading-volume name
                {total-volume: price,
                 last-price: price})
        )
        (ok true)
    )
)


(define-map name-popularity
    (string-ascii 50)
    {views: uint, last-viewed: uint})

(define-public (record-name-view (name (string-ascii 50)))
    (let ((popularity (map-get? name-popularity name)))
        (match popularity
            data (map-set name-popularity name
                {views: (+ (get views data) u1),
                 last-viewed: block-height})
            (map-set name-popularity name
                {views: u1,
                 last-viewed: block-height})
        )
        (ok true)
    )
)


(define-map name-attributes
    (string-ascii 50)
    {color: (string-ascii 7),
     font: (string-ascii 20),
     style: (string-ascii 20)})

(define-public (set-name-attributes 
    (name (string-ascii 50))
    (color (string-ascii 7))
    (font (string-ascii 20))
    (style (string-ascii 20)))
    (let ((current-owner (get-owner name)))
        (if (is-eq (some tx-sender) current-owner)
            (begin
                (map-set name-attributes name
                    {color: color,
                     font: font,
                     style: style})
                (ok true)
            )
            (err u150)
        )
    )
)


(define-constant SUBSCRIPTION_FEE u50000)
(define-map name-subscribers
    {name: (string-ascii 50), subscriber: principal}
    {active: bool, expiry: uint})

(define-public (subscribe-to-name (name (string-ascii 50)))
    (begin
        (try! (stx-transfer? SUBSCRIPTION_FEE tx-sender CONTRACT_OWNER))
        (map-set name-subscribers
            {name: name, subscriber: tx-sender}
            {active: true, expiry: (+ block-height u144)})
        (ok true)
    )
)



(define-map name-disputes
    (string-ascii 50)
    {claimant: principal, reason: (string-ascii 200), status: (string-ascii 20)})

(define-public (file-name-dispute (name (string-ascii 50)) (reason (string-ascii 200)))
    (if (is-some (map-get? names-map name))
        (begin
            (map-set name-disputes name
                {claimant: tx-sender, reason: reason, status: "pending"})
            (ok true)
        )
        (err u170)
    )
)

(define-public (resolve-dispute (name (string-ascii 50)) (resolution (string-ascii 20)))
    (if (is-eq tx-sender CONTRACT_ADMIN)
        (let ((dispute (map-get? name-disputes name)))
            (match dispute
                dispute-data (begin
                    (map-set name-disputes name
                        {claimant: (get claimant dispute-data), 
                         reason: (get reason dispute-data), 
                         status: resolution})
                    (ok true)
                )
                (err u171)
            )
        )
        (err u172)
    )
)


(define-map staked-names
    (string-ascii 50)
    {amount: uint, start-block: uint})

(define-constant STAKING_REWARD_RATE u100)
(define-constant MIN_STAKE_AMOUNT u1000000)

(define-public (stake-on-name (name (string-ascii 50)) (amount uint))
    (let ((current-owner (get-owner name)))
        (if (and 
            (is-some current-owner) 
            (is-eq (some tx-sender) current-owner)
            (>= amount MIN_STAKE_AMOUNT))
            (begin
                (try! (stx-transfer? amount tx-sender CONTRACT_OWNER))
                (map-set staked-names name
                    {amount: amount, start-block: block-height})
                (ok true)
            )
            (err u190)
        )
    )
)

(define-read-only (calculate-staking-reward (name (string-ascii 50)))
    (let ((stake-info (map-get? staked-names name)))
        (match stake-info
            stake-data (let ((blocks-staked (- block-height (get start-block stake-data))))
                (* blocks-staked STAKING_REWARD_RATE))
            u0
        )
    )
)

(define-public (claim-staking-reward (name (string-ascii 50)))
    (let ((stake-info (map-get? staked-names name))
          (current-owner (get-owner name)))
        (if (and 
            (is-some current-owner) 
            (is-eq (some tx-sender) current-owner)
            (is-some stake-info))
            (let ((reward (calculate-staking-reward name)))
                (try! (as-contract (stx-transfer? reward CONTRACT_OWNER tx-sender)))
                (map-set staked-names name
                    {amount: (get amount (unwrap-panic stake-info)), 
                     start-block: block-height})
                (ok reward)
            )
            (err u191)
        )
    )
)


(define-map name-forwards
    (string-ascii 50)
    {
        btc: (optional (string-ascii 50)),
        eth: (optional (string-ascii 50)),
        sol: (optional (string-ascii 50)),
        web: (optional (string-ascii 100))
    }
)

(define-public (set-forwards 
    (name (string-ascii 50))
    (btc-address (optional (string-ascii 50)))
    (eth-address (optional (string-ascii 50)))
    (sol-address (optional (string-ascii 50)))
    (web-url (optional (string-ascii 100))))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set name-forwards name
                    {
                        btc: btc-address,
                        eth: eth-address,
                        sol: sol-address,
                        web: web-url
                    })
                (ok true)
            )
            (err u200)
        )
    )
)

(define-read-only (get-forwards (name (string-ascii 50)))
    (map-get? name-forwards name)
)


(define-constant MAX_BATCH_SIZE u20)



(define-private (check-and-transfer 
    (name (string-ascii 50)) 
    (previous-result (response bool uint))
    (new-owner principal))
    (if (is-ok previous-result)
        (transfer-name name new-owner)
        previous-result
    )
)


(define-map name-delegates
    (string-ascii 50)
    {delegate: principal, expiry: uint})

(define-constant DELEGATE_MIN_PERIOD u1440)
(define-constant DELEGATE_MAX_PERIOD u52560)

(define-public (delegate-name (name (string-ascii 50)) (delegate principal) (period uint))
    (let ((current-owner (get-owner name)))
        (if (and 
            (is-some current-owner)
            (is-eq (some tx-sender) current-owner)
            (>= period DELEGATE_MIN_PERIOD)
            (<= period DELEGATE_MAX_PERIOD))
            (begin
                (map-set name-delegates name
                    {delegate: delegate,
                     expiry: (+ block-height period)})
                (ok true)
            )
            (err u300)
        )
    )
)

(define-public (revoke-delegation (name (string-ascii 50)))
    (let ((current-owner (get-owner name)))
        (if (and 
            (is-some current-owner)
            (is-eq (some tx-sender) current-owner))
            (begin
                (map-delete name-delegates name)
                (ok true)
            )
            (err u301)
        )
    )
)

(define-read-only (get-delegate (name (string-ascii 50)))
    (map-get? name-delegates name)
)


(define-map name-metadata
    (string-ascii 50)
    {
        tags: (list 5 (string-ascii 20)),
        image-url: (optional (string-ascii 200)),
        external-url: (optional (string-ascii 200)),
        updated-at: uint
    }
)

(define-public (set-metadata 
    (name (string-ascii 50))
    (tags (list 5 (string-ascii 20)))
    (image-url (optional (string-ascii 200)))
    (external-url (optional (string-ascii 200))))
    (let ((current-owner (get-owner name)))
        (if (and (is-some current-owner) (is-eq (some tx-sender) current-owner))
            (begin
                (map-set name-metadata name
                    {
                        tags: tags,
                        image-url: image-url,
                        external-url: external-url,
                        updated-at: block-height
                    })
                (ok true)
            )
            (err u400)
        )
    )
)

(define-read-only (get-metadata (name (string-ascii 50)))
    (map-get? name-metadata name)
)


(define-map name-escrows
    uint
    {
        name: (string-ascii 50),
        seller: principal,
        buyer: principal,
        amount: uint,
        expiry: uint,
        status: (string-ascii 10)
    }
)

(define-data-var escrow-counter uint u0)
(define-constant ESCROW_TIMEOUT u1440)

(define-public (create-escrow 
    (name (string-ascii 50)) 
    (buyer principal) 
    (amount uint) 
    (timeout-blocks uint))
    (let ((escrow-id (var-get escrow-counter))
          (current-owner (get-owner name)))
        (if (and 
            (is-some current-owner)
            (is-eq (some tx-sender) current-owner)
            (> amount u0)
            (> timeout-blocks u0))
            (begin
                (map-set name-escrows escrow-id
                    {
                        name: name,
                        seller: tx-sender,
                        buyer: buyer,
                        amount: amount,
                        expiry: (+ block-height timeout-blocks),
                        status: "active"
                    })
                (var-set escrow-counter (+ escrow-id u1))
                (ok escrow-id)
            )
            (err u500)
        )
    )
)

(define-public (fund-escrow (escrow-id uint))
    (let ((escrow (map-get? name-escrows escrow-id)))
        (match escrow
            escrow-data (if (and 
                (is-eq tx-sender (get buyer escrow-data))
                (is-eq (get status escrow-data) "active")
                (< block-height (get expiry escrow-data)))
                (begin
                    (try! (stx-transfer? (get amount escrow-data) tx-sender (as-contract tx-sender)))
                    (map-set name-escrows escrow-id
                        (merge escrow-data {status: "funded"}))
                    (ok true)
                )
                (err u501))
            (err u502)
        )
    )
)

(define-public (complete-escrow (escrow-id uint))
    (let ((escrow (map-get? name-escrows escrow-id)))
        (match escrow
            escrow-data (if (and 
                (is-eq tx-sender (get seller escrow-data))
                (is-eq (get status escrow-data) "funded")
                (< block-height (get expiry escrow-data)))
                (begin
                    (try! (transfer-name (get name escrow-data) (get buyer escrow-data)))
                    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get seller escrow-data))))
                    (map-set name-escrows escrow-id
                        (merge escrow-data {status: "completed"}))
                    (ok true)
                )
                (err u503))
            (err u504)
        )
    )
)

(define-public (cancel-escrow (escrow-id uint))
    (let ((escrow (map-get? name-escrows escrow-id)))
        (match escrow
            escrow-data (if (and 
                (or (is-eq tx-sender (get seller escrow-data)) (is-eq tx-sender (get buyer escrow-data)))
                (is-eq (get status escrow-data) "active")
                (< block-height (get expiry escrow-data)))
                (begin
                    (map-set name-escrows escrow-id
                        (merge escrow-data {status: "cancelled"}))
                    (ok true)
                )
                (err u505))
            (err u506)
        )
    )
)

(define-public (refund-expired-escrow (escrow-id uint))
    (let ((escrow (map-get? name-escrows escrow-id)))
        (match escrow
            escrow-data (if (and 
                (is-eq (get status escrow-data) "funded")
                (>= block-height (get expiry escrow-data)))
                (begin
                    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get buyer escrow-data))))
                    (map-set name-escrows escrow-id
                        (merge escrow-data {status: "expired"}))
                    (ok true)
                )
                (err u507))
            (err u508)
        )
    )
)

(define-read-only (get-escrow (escrow-id uint))
    (map-get? name-escrows escrow-id)
)

(define-read-only (get-escrow-count)
    (var-get escrow-counter)
)