;; Name Reputation & Trust System
;; Dynamic reputation scoring based on ownership behavior and community trust

;; Core reputation data structure
(define-map user-reputation 
    principal 
    {
        base-score: uint,
        ownership-score: uint,
        community-score: uint,
        verification-score: uint,
        last-updated: uint,
        total-endorsements: uint,
        negative-reports: uint
    }
)

;; Track individual name reputation contributions
(define-map name-reputation-data
    (string-ascii 50)
    {
        owner: principal,
        ownership-duration: uint,
        transfer-frequency: uint,
        verified-activities: uint,
        community-rating: uint,
        last-activity: uint
    }
)

;; Trust endorsements between users
(define-map trust-endorsements
    {endorser: principal, endorsed: principal}
    {
        trust-level: uint,
        endorsement-date: uint,
        reason: (string-ascii 100)
    }
)

;; Reputation milestone achievements
(define-map reputation-milestones
    principal
    {
        trustworthy-trader: bool,
        long-term-holder: bool,
        community-contributor: bool,
        verified-entity: bool,
        reputation-guardian: bool
    }
)

;; Reputation reports and disputes
(define-map reputation-reports
    {reporter: principal, reported: principal, report-id: uint}
    {
        report-type: (string-ascii 20),
        description: (string-ascii 200),
        severity: uint,
        status: (string-ascii 10),
        report-date: uint,
        resolution-date: (optional uint)
    }
)

(define-data-var report-counter uint u0)

;; Constants for reputation scoring
(define-constant REPUTATION_DECIMALS u1000)
(define-constant BASE_REPUTATION u5000)
(define-constant MAX_REPUTATION u10000)
(define-constant MIN_REPUTATION u0)

(define-constant OWNERSHIP_WEIGHT u30)
(define-constant COMMUNITY_WEIGHT u25)
(define-constant VERIFICATION_WEIGHT u25)
(define-constant ENDORSEMENT_WEIGHT u20)

(define-constant ENDORSEMENT_COST u10000)
(define-constant REPORT_COST u5000)
(define-constant VERIFICATION_BOOST u500)

;; Reputation levels and thresholds
(define-constant BRONZE_THRESHOLD u3000)
(define-constant SILVER_THRESHOLD u5000)
(define-constant GOLD_THRESHOLD u7000)
(define-constant PLATINUM_THRESHOLD u8500)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_INVALID_PARAMS u1002)
(define-constant ERR_ALREADY_ENDORSED u1003)
(define-constant ERR_SELF_ENDORSEMENT u1004)
(define-constant ERR_INSUFFICIENT_REPUTATION u1005)
(define-constant ERR_REPORT_EXISTS u1006)
(define-constant ERR_INVALID_TRUST_LEVEL u1007)

;; Initialize reputation for a new user
(define-public (initialize-reputation (user principal))
    (begin
        (asserts! (is-none (map-get? user-reputation user)) (err ERR_ALREADY_ENDORSED))
        (map-set user-reputation user
            {
                base-score: BASE_REPUTATION,
                ownership-score: u0,
                community-score: u0,
                verification-score: u0,
                last-updated: block-height,
                total-endorsements: u0,
                negative-reports: u0
            }
        )
        (map-set reputation-milestones user
            {
                trustworthy-trader: false,
                long-term-holder: false,
                community-contributor: false,
                verified-entity: false,
                reputation-guardian: false
            }
        )
        (ok true)
    )
)

;; Endorse another user's reputation
(define-public (endorse-user (endorsed principal) (trust-level uint) (reason (string-ascii 100)))
    (let ((endorser tx-sender)
          (endorser-rep (get-user-reputation endorser))
          (endorsed-rep (get-user-reputation endorsed)))
        (asserts! (not (is-eq endorser endorsed)) (err ERR_SELF_ENDORSEMENT))
        (asserts! (and (>= trust-level u1) (<= trust-level u5)) (err ERR_INVALID_TRUST_LEVEL))
        (asserts! (>= endorser-rep SILVER_THRESHOLD) (err ERR_INSUFFICIENT_REPUTATION))
        (asserts! (is-none (map-get? trust-endorsements {endorser: endorser, endorsed: endorsed})) (err ERR_ALREADY_ENDORSED))
        
        (try! (stx-transfer? ENDORSEMENT_COST endorser (as-contract tx-sender)))
        
        (map-set trust-endorsements 
            {endorser: endorser, endorsed: endorsed}
            {
                trust-level: trust-level,
                endorsement-date: block-height,
                reason: reason
            }
        )
        
        (let ((current-rep (default-to 
                {base-score: BASE_REPUTATION, ownership-score: u0, community-score: u0, verification-score: u0, last-updated: u0, total-endorsements: u0, negative-reports: u0}
                (map-get? user-reputation endorsed))))
            (map-set user-reputation endorsed
                (merge current-rep {
                    total-endorsements: (+ (get total-endorsements current-rep) u1),
                    community-score: (+ (get community-score current-rep) (* trust-level u100)),
                    last-updated: block-height
                })
            )
        )
        (ok true)
    )
)

;; Report suspicious or negative behavior
(define-public (report-user (reported principal) (report-type (string-ascii 20)) (description (string-ascii 200)) (severity uint))
    (let ((reporter tx-sender)
          (report-id (var-get report-counter))
          (reporter-rep (get-user-reputation reporter)))
        (asserts! (not (is-eq reporter reported)) (err ERR_SELF_ENDORSEMENT))
        (asserts! (and (>= severity u1) (<= severity u5)) (err ERR_INVALID_PARAMS))
        (asserts! (>= reporter-rep BRONZE_THRESHOLD) (err ERR_INSUFFICIENT_REPUTATION))
        
        (try! (stx-transfer? REPORT_COST reporter (as-contract tx-sender)))
        
        (map-set reputation-reports
            {reporter: reporter, reported: reported, report-id: report-id}
            {
                report-type: report-type,
                description: description,
                severity: severity,
                status: "pending",
                report-date: block-height,
                resolution-date: none
            }
        )
        
        (var-set report-counter (+ report-id u1))
        
        (let ((current-rep (default-to 
                {base-score: BASE_REPUTATION, ownership-score: u0, community-score: u0, verification-score: u0, last-updated: u0, total-endorsements: u0, negative-reports: u0}
                (map-get? user-reputation reported))))
            (map-set user-reputation reported
                (merge current-rep {
                    negative-reports: (+ (get negative-reports current-rep) u1),
                    community-score: (if (> (get community-score current-rep) (* severity u50))
                        (- (get community-score current-rep) (* severity u50))
                        u0),
                    last-updated: block-height
                })
            )
        )
        (ok report-id)
    )
)

;; Update name ownership contribution to reputation
(define-public (update-name-reputation (name (string-ascii 50)) (owner principal))
    (let ((name-data (default-to 
            {owner: owner, ownership-duration: u0, transfer-frequency: u0, verified-activities: u0, community-rating: u0, last-activity: u0}
            (map-get? name-reputation-data name)))
          (ownership-blocks (- block-height (get last-activity name-data))))
        
        (map-set name-reputation-data name
            (merge name-data {
                owner: owner,
                ownership-duration: (+ (get ownership-duration name-data) ownership-blocks),
                last-activity: block-height
            })
        )
        
        (let ((user-rep (default-to 
                {base-score: BASE_REPUTATION, ownership-score: u0, community-score: u0, verification-score: u0, last-updated: u0, total-endorsements: u0, negative-reports: u0}
                (map-get? user-reputation owner)))
              (ownership-bonus (/ ownership-blocks u100)))
            (map-set user-reputation owner
                (merge user-rep {
                    ownership-score: (+ (get ownership-score user-rep) ownership-bonus),
                    last-updated: block-height
                })
            )
        )
        (ok true)
    )
)

;; Calculate total reputation score
(define-read-only (get-user-reputation (user principal))
    (let ((rep-data (map-get? user-reputation user)))
        (match rep-data
            data (let ((base (get base-score data))
                       (ownership (* (get ownership-score data) OWNERSHIP_WEIGHT))
                       (community (* (get community-score data) COMMUNITY_WEIGHT))
                       (verification (* (get verification-score data) VERIFICATION_WEIGHT))
                       (endorsements (* (get total-endorsements data) ENDORSEMENT_WEIGHT))
                       (penalties (* (get negative-reports data) u200)))
                (let ((total-score (+ base ownership community verification endorsements)))
                    (if (> total-score penalties)
                        (let ((final-score (- total-score penalties)))
                            (if (> final-score MAX_REPUTATION)
                                MAX_REPUTATION
                                final-score))
                        MIN_REPUTATION)))
            BASE_REPUTATION
        )
    )
)

;; Get reputation level based on score
(define-read-only (get-reputation-level (user principal))
    (let ((score (get-user-reputation user)))
        (if (>= score PLATINUM_THRESHOLD)
            "Platinum"
            (if (>= score GOLD_THRESHOLD)
                "Gold"
                (if (>= score SILVER_THRESHOLD)
                    "Silver"
                    (if (>= score BRONZE_THRESHOLD)
                        "Bronze"
                        "Novice"
                    )
                )
            )
        )
    )
)

;; Award verification boost for completing verified activities
(define-public (award-verification-boost (user principal) (activity-type (string-ascii 30)))
    (let ((user-rep (default-to 
            {base-score: BASE_REPUTATION, ownership-score: u0, community-score: u0, verification-score: u0, last-updated: u0, total-endorsements: u0, negative-reports: u0}
            (map-get? user-reputation user))))
        (map-set user-reputation user
            (merge user-rep {
                verification-score: (+ (get verification-score user-rep) VERIFICATION_BOOST),
                last-updated: block-height
            })
        )
        (ok true)
    )
)

;; Check if user qualifies for reputation-based benefits
(define-read-only (get-fee-discount (user principal))
    (let ((level (get-reputation-level user)))
        (if (is-eq level "Platinum")
            u50  ;; 50% discount
            (if (is-eq level "Gold")
                u30  ;; 30% discount
                (if (is-eq level "Silver")
                    u15  ;; 15% discount
                    (if (is-eq level "Bronze")
                        u5   ;; 5% discount
                        u0   ;; No discount
                    )
                )
            )
        )
    )
)

;; Get endorsement between two users
(define-read-only (get-endorsement (endorser principal) (endorsed principal))
    (map-get? trust-endorsements {endorser: endorser, endorsed: endorsed})
)

;; Get reputation report details
(define-read-only (get-report (reporter principal) (reported principal) (report-id uint))
    (map-get? reputation-reports {reporter: reporter, reported: reported, report-id: report-id})
)

;; Get name reputation data
(define-read-only (get-name-reputation (name (string-ascii 50)))
    (map-get? name-reputation-data name)
)

;; Get user reputation milestones
(define-read-only (get-user-milestones (user principal))
    (map-get? reputation-milestones user)
)

;; Get total number of reports
(define-read-only (get-total-reports)
    (var-get report-counter)
)

;; Award milestone achievements based on reputation thresholds
(define-public (check-and-award-milestones (user principal))
    (let ((reputation (get-user-reputation user))
          (current-milestones (default-to 
            {trustworthy-trader: false, long-term-holder: false, community-contributor: false, verified-entity: false, reputation-guardian: false}
            (map-get? reputation-milestones user)))
          (user-data (map-get? user-reputation user)))
        (match user-data
            data (let ((new-milestones 
                    {
                        trustworthy-trader: (or (get trustworthy-trader current-milestones) (>= reputation SILVER_THRESHOLD)),
                        long-term-holder: (or (get long-term-holder current-milestones) (>= (get ownership-score data) u1000)),
                        community-contributor: (or (get community-contributor current-milestones) (>= (get total-endorsements data) u5)),
                        verified-entity: (or (get verified-entity current-milestones) (>= (get verification-score data) u2000)),
                        reputation-guardian: (or (get reputation-guardian current-milestones) (>= reputation PLATINUM_THRESHOLD))
                    }))
                (map-set reputation-milestones user new-milestones)
                (ok new-milestones))
            (err ERR_UNAUTHORIZED)
        )
    )
)

