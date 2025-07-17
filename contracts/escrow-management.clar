;; Escrow Management Contract
;; Manages secure fund holding for property transactions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-EXPIRED (err u106))

;; Data Variables
(define-data-var next-escrow-id uint u1)

;; Data Maps
(define-map escrow-agreements
  { escrow-id: uint }
  {
    property-id: uint,
    buyer: principal,
    seller: principal,
    escrow-agent: principal,
    amount: uint,
    deposit-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    conditions-met: uint,
    total-conditions: uint
  }
)

(define-map escrow-conditions
  { escrow-id: uint, condition-id: uint }
  {
    description: (string-ascii 200),
    responsible-party: principal,
    is-met: bool,
    verification-date: (optional uint),
    verifier: (optional principal)
  }
)

(define-map escrow-funds
  { escrow-id: uint }
  {
    deposited-amount: uint,
    held-amount: uint,
    released-amount: uint,
    refunded-amount: uint
  }
)

(define-map escrow-transactions
  { escrow-id: uint, transaction-id: uint }
  {
    transaction-type: (string-ascii 20),
    amount: uint,
    recipient: principal,
    transaction-date: uint,
    notes: (optional (string-ascii 200))
  }
)

(define-map agent-credentials
  { agent: principal }
  {
    is-licensed: bool,
    license-date: uint,
    total-escrows: uint,
    success-rate: uint
  }
)

;; Private Functions
(define-private (is-escrow-party (escrow-id uint) (caller principal))
  (match (map-get? escrow-agreements { escrow-id: escrow-id })
    agreement (or
      (is-eq (get buyer agreement) caller)
      (is-eq (get seller agreement) caller)
      (is-eq (get escrow-agent agreement) caller)
    )
    false
  )
)

(define-private (is-escrow-agent (escrow-id uint) (caller principal))
  (match (map-get? escrow-agreements { escrow-id: escrow-id })
    agreement (is-eq (get escrow-agent agreement) caller)
    false
  )
)

(define-private (is-licensed-agent (agent principal))
  (match (map-get? agent-credentials { agent: agent })
    credentials (get is-licensed credentials)
    false
  )
)

(define-private (calculate-expiry-date (duration-days uint))
  (+ block-height (* duration-days u144)) ;; Approximate blocks per day
)

(define-private (get-transaction-count (escrow-id uint))
  (fold + (list u1 u1 u1 u1 u1) u0) ;; Simplified counter
)

;; Public Functions
(define-public (register-escrow-agent)
  (begin
    (map-set agent-credentials
      { agent: tx-sender }
      {
        is-licensed: false,
        license-date: block-height,
        total-escrows: u0,
        success-rate: u0
      }
    )

    (ok true)
  )
)

(define-public (license-escrow-agent (agent principal))
  (let
    (
      (credentials (unwrap! (map-get? agent-credentials { agent: agent }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set agent-credentials
      { agent: agent }
      (merge credentials { is-licensed: true })
    )

    (ok true)
  )
)

(define-public (create-escrow (property-id uint) (seller principal) (escrow-agent principal) (amount uint) (duration-days uint))
  (let
    (
      (escrow-id (var-get next-escrow-id))
      (expiry-date (calculate-expiry-date duration-days))
    )
    (asserts! (> property-id u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tx-sender seller)) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tx-sender escrow-agent)) ERR-INVALID-INPUT)
    (asserts! (not (is-eq seller escrow-agent)) ERR-INVALID-INPUT)
    (asserts! (is-licensed-agent escrow-agent) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (<= duration-days u365) ERR-INVALID-INPUT) ;; Max 1 year

    (map-set escrow-agreements
      { escrow-id: escrow-id }
      {
        property-id: property-id,
        buyer: tx-sender,
        seller: seller,
        escrow-agent: escrow-agent,
        amount: amount,
        deposit-date: block-height,
        expiry-date: expiry-date,
        status: "pending",
        conditions-met: u0,
        total-conditions: u0
      }
    )

    (map-set escrow-funds
      { escrow-id: escrow-id }
      {
        deposited-amount: u0,
        held-amount: u0,
        released-amount: u0,
        refunded-amount: u0
      }
    )

    (var-set next-escrow-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

(define-public (deposit-funds (escrow-id uint) (amount uint))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (funds (unwrap! (map-get? escrow-funds { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (transaction-id (get-transaction-count escrow-id))
    )
    (asserts! (is-eq (get buyer agreement) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "pending") ERR-INVALID-STATUS)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (<= (+ (get deposited-amount funds) amount) (get amount agreement)) ERR-INVALID-INPUT)

    ;; Update funds
    (map-set escrow-funds
      { escrow-id: escrow-id }
      (merge funds {
        deposited-amount: (+ (get deposited-amount funds) amount),
        held-amount: (+ (get held-amount funds) amount)
      })
    )

    ;; Record transaction
    (map-set escrow-transactions
      { escrow-id: escrow-id, transaction-id: transaction-id }
      {
        transaction-type: "deposit",
        amount: amount,
        recipient: tx-sender,
        transaction-date: block-height,
        notes: none
      }
    )

    ;; Activate escrow if fully funded
    (if (is-eq (+ (get deposited-amount funds) amount) (get amount agreement))
      (map-set escrow-agreements
        { escrow-id: escrow-id }
        (merge agreement { status: "active" })
      )
      true
    )

    (ok true)
  )
)

(define-public (add-condition (escrow-id uint) (description (string-ascii 200)) (responsible-party principal))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (condition-id (get total-conditions agreement))
    )
    (asserts! (is-escrow-agent escrow-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "active") ERR-INVALID-STATUS)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (or
      (is-eq responsible-party (get buyer agreement))
      (is-eq responsible-party (get seller agreement))
    ) ERR-INVALID-INPUT)

    (map-set escrow-conditions
      { escrow-id: escrow-id, condition-id: condition-id }
      {
        description: description,
        responsible-party: responsible-party,
        is-met: false,
        verification-date: none,
        verifier: none
      }
    )

    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge agreement { total-conditions: (+ condition-id u1) })
    )

    (ok condition-id)
  )
)

(define-public (verify-condition (escrow-id uint) (condition-id uint))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (condition (unwrap! (map-get? escrow-conditions { escrow-id: escrow-id, condition-id: condition-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-escrow-agent escrow-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "active") ERR-INVALID-STATUS)
    (asserts! (not (get is-met condition)) ERR-INVALID-STATUS)

    (map-set escrow-conditions
      { escrow-id: escrow-id, condition-id: condition-id }
      (merge condition {
        is-met: true,
        verification-date: (some block-height),
        verifier: (some tx-sender)
      })
    )

    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge agreement { conditions-met: (+ (get conditions-met agreement) u1) })
    )

    (ok true)
  )
)

(define-public (release-funds (escrow-id uint))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (funds (unwrap! (map-get? escrow-funds { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (transaction-id (get-transaction-count escrow-id))
    )
    (asserts! (is-escrow-agent escrow-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "active") ERR-INVALID-STATUS)
    (asserts! (is-eq (get conditions-met agreement) (get total-conditions agreement)) ERR-INVALID-STATUS)
    (asserts! (> (get held-amount funds) u0) ERR-INSUFFICIENT-FUNDS)

    ;; Update funds
    (map-set escrow-funds
      { escrow-id: escrow-id }
      (merge funds {
        held-amount: u0,
        released-amount: (+ (get released-amount funds) (get held-amount funds))
      })
    )

    ;; Record transaction
    (map-set escrow-transactions
      { escrow-id: escrow-id, transaction-id: transaction-id }
      {
        transaction-type: "release",
        amount: (get held-amount funds),
        recipient: (get seller agreement),
        transaction-date: block-height,
        notes: (some "All conditions met - funds released to seller")
      }
    )

    ;; Update agreement status
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge agreement { status: "completed" })
    )

    ;; Update agent stats
    (match (map-get? agent-credentials { agent: tx-sender })
      credentials
        (map-set agent-credentials
          { agent: tx-sender }
          (merge credentials {
            total-escrows: (+ (get total-escrows credentials) u1),
            success-rate: u100 ;; Simplified success rate
          })
        )
      false
    )

    (ok true)
  )
)

(define-public (refund-funds (escrow-id uint) (reason (string-ascii 200)))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (funds (unwrap! (map-get? escrow-funds { escrow-id: escrow-id }) ERR-NOT-FOUND))
      (transaction-id (get-transaction-count escrow-id))
    )
    (asserts! (is-escrow-agent escrow-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "active") ERR-INVALID-STATUS)
    (asserts! (> (get held-amount funds) u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)

    ;; Update funds
    (map-set escrow-funds
      { escrow-id: escrow-id }
      (merge funds {
        held-amount: u0,
        refunded-amount: (+ (get refunded-amount funds) (get held-amount funds))
      })
    )

    ;; Record transaction
    (map-set escrow-transactions
      { escrow-id: escrow-id, transaction-id: transaction-id }
      {
        transaction-type: "refund",
        amount: (get held-amount funds),
        recipient: (get buyer agreement),
        transaction-date: block-height,
        notes: (some reason)
      }
    )

    ;; Update agreement status
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge agreement { status: "refunded" })
    )

    (ok true)
  )
)

(define-public (cancel-escrow (escrow-id uint))
  (let
    (
      (agreement (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-escrow-party escrow-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (or
      (is-eq (get status agreement) "pending")
      (>= block-height (get expiry-date agreement))
    ) ERR-INVALID-STATUS)

    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge agreement { status: "cancelled" })
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-escrow-agreement (escrow-id uint))
  (map-get? escrow-agreements { escrow-id: escrow-id })
)

(define-read-only (get-escrow-funds (escrow-id uint))
  (map-get? escrow-funds { escrow-id: escrow-id })
)

(define-read-only (get-escrow-condition (escrow-id uint) (condition-id uint))
  (map-get? escrow-conditions { escrow-id: escrow-id, condition-id: condition-id })
)

(define-read-only (get-escrow-transaction (escrow-id uint) (transaction-id uint))
  (map-get? escrow-transactions { escrow-id: escrow-id, transaction-id: transaction-id })
)

(define-read-only (get-agent-credentials (agent principal))
  (map-get? agent-credentials { agent: agent })
)

(define-read-only (is-escrow-ready-for-release (escrow-id uint))
  (match (map-get? escrow-agreements { escrow-id: escrow-id })
    agreement (and
      (is-eq (get status agreement) "active")
      (is-eq (get conditions-met agreement) (get total-conditions agreement))
    )
    false
  )
)

(define-read-only (is-escrow-expired (escrow-id uint))
  (match (map-get? escrow-agreements { escrow-id: escrow-id })
    agreement (>= block-height (get expiry-date agreement))
    false
  )
)

(define-read-only (get-escrow-balance (escrow-id uint))
  (match (map-get? escrow-funds { escrow-id: escrow-id })
    funds (get held-amount funds)
    u0
  )
)

(define-read-only (get-next-escrow-id)
  (var-get next-escrow-id)
)
