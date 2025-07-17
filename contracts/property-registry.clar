;; Property Registry Contract
;; Manages property ownership and registration

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))

;; Data Variables
(define-data-var next-property-id uint u1)

;; Data Maps
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    address: (string-ascii 200),
    property-type: (string-ascii 50),
    square-footage: uint,
    registration-date: uint,
    is-active: bool
  }
)

(define-map property-history
  { property-id: uint, transfer-id: uint }
  {
    previous-owner: principal,
    new-owner: principal,
    transfer-date: uint,
    transfer-price: (optional uint)
  }
)

(define-map owner-properties
  { owner: principal }
  { property-count: uint }
)

;; Private Functions
(define-private (is-property-owner (property-id uint) (caller principal))
  (match (map-get? properties { property-id: property-id })
    property (is-eq (get owner property) caller)
    false
  )
)

;; Public Functions
(define-public (register-property (address (string-ascii 200)) (property-type (string-ascii 50)) (square-footage uint))
  (let
    (
      (property-id (var-get next-property-id))
      (current-block-height block-height)
    )
    (asserts! (> (len address) u0) ERR-INVALID-INPUT)
    (asserts! (> (len property-type) u0) ERR-INVALID-INPUT)
    (asserts! (> square-footage u0) ERR-INVALID-INPUT)

    (map-set properties
      { property-id: property-id }
      {
        owner: tx-sender,
        address: address,
        property-type: property-type,
        square-footage: square-footage,
        registration-date: current-block-height,
        is-active: true
      }
    )

    (map-set owner-properties
      { owner: tx-sender }
      { property-count: (+ (get-owner-property-count tx-sender) u1) }
    )

    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

(define-public (transfer-property (property-id uint) (new-owner principal) (transfer-price (optional uint)))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-NOT-FOUND))
      (current-owner (get owner property))
      (transfer-id (get-transfer-count property-id))
    )
    (asserts! (is-eq tx-sender current-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq current-owner new-owner)) ERR-INVALID-INPUT)

    ;; Update property ownership
    (map-set properties
      { property-id: property-id }
      (merge property { owner: new-owner })
    )

    ;; Record transfer history
    (map-set property-history
      { property-id: property-id, transfer-id: transfer-id }
      {
        previous-owner: current-owner,
        new-owner: new-owner,
        transfer-date: block-height,
        transfer-price: transfer-price
      }
    )

    ;; Update owner property counts
    (map-set owner-properties
      { owner: current-owner }
      { property-count: (- (get-owner-property-count current-owner) u1) }
    )

    (map-set owner-properties
      { owner: new-owner }
      { property-count: (+ (get-owner-property-count new-owner) u1) }
    )

    (ok true)
  )
)

(define-public (update-property-details (property-id uint) (address (string-ascii 200)) (property-type (string-ascii 50)) (square-footage uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-property-owner property-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len address) u0) ERR-INVALID-INPUT)
    (asserts! (> (len property-type) u0) ERR-INVALID-INPUT)
    (asserts! (> square-footage u0) ERR-INVALID-INPUT)

    (map-set properties
      { property-id: property-id }
      (merge property {
        address: address,
        property-type: property-type,
        square-footage: square-footage
      })
    )

    (ok true)
  )
)

(define-public (deactivate-property (property-id uint))
  (let
    (
      (property (unwrap! (map-get? properties { property-id: property-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-property-owner property-id tx-sender) ERR-NOT-AUTHORIZED)

    (map-set properties
      { property-id: property-id }
      (merge property { is-active: false })
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-property-owner (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property (some (get owner property))
    none
  )
)

(define-read-only (get-owner-property-count (owner principal))
  (default-to u0 (get property-count (map-get? owner-properties { owner: owner })))
)

(define-read-only (get-transfer-history (property-id uint) (transfer-id uint))
  (map-get? property-history { property-id: property-id, transfer-id: transfer-id })
)

(define-read-only (get-transfer-count (property-id uint))
  (fold + (list u1 u1 u1 u1 u1 u1 u1 u1 u1 u1) u0)
)

(define-read-only (get-next-property-id)
  (var-get next-property-id)
)

(define-read-only (is-valid-property (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property (get is-active property)
    false
  )
)
