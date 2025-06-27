;; Behavior Analysis Contract
;; Analyzes and tracks customer behavior patterns

;; Constants
(define-constant err-unauthorized (err u200))
(define-constant err-invalid-data (err u201))
(define-constant err-not-found (err u202))

;; Data Variables
(define-data-var next-behavior-id uint u1)
(define-data-var total-behaviors uint u0)

;; Data Maps
(define-map customer-behaviors
  { behavior-id: uint }
  {
    customer-id: (string-ascii 50),
    action-type: (string-ascii 30),
    timestamp: uint,
    value: uint,
    metadata: (string-ascii 200),
    analyzer: principal
  }
)

(define-map customer-stats
  { customer-id: (string-ascii 50) }
  {
    total-actions: uint,
    last-activity: uint,
    engagement-score: uint,
    reward-tokens: uint
  }
)

(define-map behavior-patterns
  { pattern-id: uint }
  {
    customer-id: (string-ascii 50),
    pattern-type: (string-ascii 30),
    frequency: uint,
    confidence: uint,
    created-at: uint
  }
)

;; Public Functions

;; Record customer behavior
(define-public (record-behavior
  (customer-id (string-ascii 50))
  (action-type (string-ascii 30))
  (value uint)
  (metadata (string-ascii 200))
)
  (let
    (
      (behavior-id (var-get next-behavior-id))
      (current-stats (default-to
        { total-actions: u0, last-activity: u0, engagement-score: u0, reward-tokens: u0 }
        (map-get? customer-stats { customer-id: customer-id })
      ))
    )
    (asserts! (> (len customer-id) u0) err-invalid-data)
    (asserts! (> (len action-type) u0) err-invalid-data)

    (map-set customer-behaviors
      { behavior-id: behavior-id }
      {
        customer-id: customer-id,
        action-type: action-type,
        timestamp: block-height,
        value: value,
        metadata: metadata,
        analyzer: tx-sender
      }
    )

    (map-set customer-stats
      { customer-id: customer-id }
      {
        total-actions: (+ (get total-actions current-stats) u1),
        last-activity: block-height,
        engagement-score: (+ (get engagement-score current-stats) value),
        reward-tokens: (+ (get reward-tokens current-stats) u10)
      }
    )

    (var-set next-behavior-id (+ behavior-id u1))
    (var-set total-behaviors (+ (var-get total-behaviors) u1))
    (ok behavior-id)
  )
)

;; Create behavior pattern
(define-public (create-pattern
  (customer-id (string-ascii 50))
  (pattern-type (string-ascii 30))
  (frequency uint)
  (confidence uint)
)
  (let
    (
      (pattern-id (var-get next-behavior-id))
    )
    (asserts! (> (len customer-id) u0) err-invalid-data)
    (asserts! (> (len pattern-type) u0) err-invalid-data)
    (asserts! (<= confidence u100) err-invalid-data)

    (map-set behavior-patterns
      { pattern-id: pattern-id }
      {
        customer-id: customer-id,
        pattern-type: pattern-type,
        frequency: frequency,
        confidence: confidence,
        created-at: block-height
      }
    )

    (ok pattern-id)
  )
)

;; Update engagement score
(define-public (update-engagement-score (customer-id (string-ascii 50)) (score uint))
  (let
    (
      (current-stats (unwrap! (map-get? customer-stats { customer-id: customer-id }) err-not-found))
    )
    (map-set customer-stats
      { customer-id: customer-id }
      (merge current-stats { engagement-score: score })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get behavior by ID
(define-read-only (get-behavior (behavior-id uint))
  (map-get? customer-behaviors { behavior-id: behavior-id })
)

;; Get customer statistics
(define-read-only (get-customer-stats (customer-id (string-ascii 50)))
  (map-get? customer-stats { customer-id: customer-id })
)

;; Get behavior pattern
(define-read-only (get-pattern (pattern-id uint))
  (map-get? behavior-patterns { pattern-id: pattern-id })
)

;; Get total behaviors recorded
(define-read-only (get-total-behaviors)
  (var-get total-behaviors)
)
