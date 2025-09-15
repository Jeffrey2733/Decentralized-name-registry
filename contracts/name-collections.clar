;; Name Collections System
;; Allows users to create and manage curated collections of names

;; Constants and error codes
(define-constant ERR_UNAUTHORIZED u2001)
(define-constant ERR_COLLECTION_NOT_FOUND u2002)
(define-constant ERR_COLLECTION_EXISTS u2003)
(define-constant ERR_COLLECTION_FULL u2004)
(define-constant ERR_NAME_NOT_OWNED u2005)
(define-constant ERR_NAME_ALREADY_IN_COLLECTION u2006)
(define-constant ERR_INVALID_PARAMETERS u2007)
(define-constant ERR_COLLECTION_PRIVATE u2008)

(define-constant MAX_COLLECTION_SIZE u50)
(define-constant MAX_COLLECTIONS_PER_USER u20)
(define-constant COLLECTION_CREATION_FEE u100000) ;; 0.1 STX

;; Data structures
(define-map collections
    {creator: principal, collection-id: (string-ascii 30)}
    {
        title: (string-ascii 100),
        description: (string-ascii 200),
        created-at: uint,
        is-public: bool,
        total-names: uint,
        tags: (list 5 (string-ascii 20))
    }
)

(define-map collection-names
    {creator: principal, collection-id: (string-ascii 30), name: (string-ascii 50)}
    {
        added-at: uint,
        position: uint
    }
)

(define-map user-collection-count principal uint)

(define-map collection-followers
    {creator: principal, collection-id: (string-ascii 30), follower: principal}
    {
        followed-at: uint,
        notifications: bool
    }
)

(define-map collection-stats
    {creator: principal, collection-id: (string-ascii 30)}
    {
        total-followers: uint,
        total-views: uint,
        last-updated: uint
    }
)

;; Helper function to check name ownership (simplified for this contract)
(define-private (owns-name (name (string-ascii 50)) (owner principal))
    ;; In real implementation, this would call the main name-registry contract
    ;; For now, we assume all names are owned by the caller
    true
)

;; Create a new collection
(define-public (create-collection 
    (collection-id (string-ascii 30))
    (title (string-ascii 100))
    (description (string-ascii 200))
    (is-public bool)
    (tags (list 5 (string-ascii 20))))
    (let ((creator tx-sender)
          (user-count (default-to u0 (map-get? user-collection-count creator))))
        ;; Check if user hasn't exceeded collection limit
        (asserts! (< user-count MAX_COLLECTIONS_PER_USER) (err ERR_INVALID_PARAMETERS))
        
        ;; Check if collection doesn't already exist
        (asserts! (is-none (map-get? collections {creator: creator, collection-id: collection-id})) 
                  (err ERR_COLLECTION_EXISTS))
        
        ;; Pay creation fee
        (try! (stx-transfer? COLLECTION_CREATION_FEE creator (as-contract tx-sender)))
        
        ;; Create collection
        (map-set collections 
            {creator: creator, collection-id: collection-id}
            {
                title: title,
                description: description,
                created-at: block-height,
                is-public: is-public,
                total-names: u0,
                tags: tags
            }
        )
        
        ;; Initialize collection stats
        (map-set collection-stats
            {creator: creator, collection-id: collection-id}
            {
                total-followers: u0,
                total-views: u0,
                last-updated: block-height
            }
        )
        
        ;; Update user collection count
        (map-set user-collection-count creator (+ user-count u1))
        
        (ok true)
    )
)

;; Add a name to collection
(define-public (add-name-to-collection 
    (collection-id (string-ascii 30))
    (name (string-ascii 50)))
    (let ((creator tx-sender)
          (collection (map-get? collections {creator: creator, collection-id: collection-id})))
        (match collection
            collection-data 
                (begin
                    ;; Check collection size limit
                    (asserts! (< (get total-names collection-data) MAX_COLLECTION_SIZE) 
                              (err ERR_COLLECTION_FULL))
                    
                    ;; Check name ownership (simplified)
                    (asserts! (owns-name name creator) (err ERR_NAME_NOT_OWNED))
                    
                    ;; Check if name is not already in collection
                    (asserts! (is-none (map-get? collection-names 
                                                {creator: creator, collection-id: collection-id, name: name}))
                              (err ERR_NAME_ALREADY_IN_COLLECTION))
                    
                    ;; Add name to collection
                    (map-set collection-names
                        {creator: creator, collection-id: collection-id, name: name}
                        {
                            added-at: block-height,
                            position: (get total-names collection-data)
                        }
                    )
                    
                    ;; Update collection data
                    (map-set collections 
                        {creator: creator, collection-id: collection-id}
                        (merge collection-data {
                            total-names: (+ (get total-names collection-data) u1)
                        })
                    )
                    
                    ;; Update stats
                    (let ((stats (default-to 
                                    {total-followers: u0, total-views: u0, last-updated: u0}
                                    (map-get? collection-stats {creator: creator, collection-id: collection-id}))))
                        (map-set collection-stats 
                            {creator: creator, collection-id: collection-id}
                            (merge stats {last-updated: block-height})
                        )
                    )
                    
                    (ok true)
                )
            (err ERR_COLLECTION_NOT_FOUND)
        )
    )
)

;; Remove name from collection
(define-public (remove-name-from-collection 
    (collection-id (string-ascii 30))
    (name (string-ascii 50)))
    (let ((creator tx-sender)
          (collection (map-get? collections {creator: creator, collection-id: collection-id})))
        (match collection
            collection-data 
                (begin
                    ;; Check if name exists in collection
                    (asserts! (is-some (map-get? collection-names 
                                                {creator: creator, collection-id: collection-id, name: name}))
                              (err ERR_NAME_NOT_OWNED))
                    
                    ;; Remove name from collection
                    (map-delete collection-names {creator: creator, collection-id: collection-id, name: name})
                    
                    ;; Update collection data
                    (map-set collections 
                        {creator: creator, collection-id: collection-id}
                        (merge collection-data {
                            total-names: (if (> (get total-names collection-data) u0)
                                           (- (get total-names collection-data) u1)
                                           u0)
                        })
                    )
                    
                    (ok true)
                )
            (err ERR_COLLECTION_NOT_FOUND)
        )
    )
)

;; Follow a collection
(define-public (follow-collection (creator principal) (collection-id (string-ascii 30)))
    (let ((follower tx-sender)
          (collection (map-get? collections {creator: creator, collection-id: collection-id})))
        (match collection
            collection-data
                (if (get is-public collection-data)
                    (begin
                        ;; Check if not already following
                        (asserts! (is-none (map-get? collection-followers 
                                                    {creator: creator, collection-id: collection-id, follower: follower}))
                                  (err ERR_NAME_ALREADY_IN_COLLECTION))
                        
                        ;; Add follower
                        (map-set collection-followers
                            {creator: creator, collection-id: collection-id, follower: follower}
                            {
                                followed-at: block-height,
                                notifications: true
                            }
                        )
                        
                        ;; Update stats
                        (let ((stats (default-to 
                                        {total-followers: u0, total-views: u0, last-updated: u0}
                                        (map-get? collection-stats {creator: creator, collection-id: collection-id}))))
                            (map-set collection-stats 
                                {creator: creator, collection-id: collection-id}
                                (merge stats {total-followers: (+ (get total-followers stats) u1)})
                            )
                        )
                        
                        (ok true)
                    )
                    (err ERR_COLLECTION_PRIVATE)
                )
            (err ERR_COLLECTION_NOT_FOUND)
        )
    )
)

;; Unfollow a collection
(define-public (unfollow-collection (creator principal) (collection-id (string-ascii 30)))
    (let ((follower tx-sender)
          (follow-data (map-get? collection-followers 
                                {creator: creator, collection-id: collection-id, follower: follower})))
        (match follow-data
            data
                (begin
                    ;; Remove follower
                    (map-delete collection-followers 
                               {creator: creator, collection-id: collection-id, follower: follower})
                    
                    ;; Update stats
                    (let ((stats (default-to 
                                    {total-followers: u0, total-views: u0, last-updated: u0}
                                    (map-get? collection-stats {creator: creator, collection-id: collection-id}))))
                        (map-set collection-stats 
                            {creator: creator, collection-id: collection-id}
                            (merge stats {
                                total-followers: (if (> (get total-followers stats) u0)
                                                   (- (get total-followers stats) u1)
                                                   u0)
                            })
                        )
                    )
                    
                    (ok true)
                )
            (err ERR_UNAUTHORIZED)
        )
    )
)

;; Read-only functions
(define-read-only (get-collection (creator principal) (collection-id (string-ascii 30)))
    (map-get? collections {creator: creator, collection-id: collection-id})
)

(define-read-only (get-collection-stats (creator principal) (collection-id (string-ascii 30)))
    (map-get? collection-stats {creator: creator, collection-id: collection-id})
)

(define-read-only (is-name-in-collection (creator principal) (collection-id (string-ascii 30)) (name (string-ascii 50)))
    (is-some (map-get? collection-names {creator: creator, collection-id: collection-id, name: name}))
)

(define-read-only (is-following-collection (creator principal) (collection-id (string-ascii 30)) (follower principal))
    (is-some (map-get? collection-followers {creator: creator, collection-id: collection-id, follower: follower}))
)

(define-read-only (get-user-collection-count (user principal))
    (default-to u0 (map-get? user-collection-count user))
)
