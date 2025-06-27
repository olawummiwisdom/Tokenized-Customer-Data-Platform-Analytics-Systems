;; Journey Mapping Contract
;; Maps and tracks customer journeys across touchpoints

;; Constants
(define-constant err-unauthorized (err u300))
(define-constant err-invalid-data (err u301))
(define-constant err-not-found (err u302))
(define-constant err-journey-complete (err u303))

;; Data Variables
(define-data-var next-journey-id uint u1)
(define-data-var next-milestone-id uint u1)

;; Data Maps
(define-map customer-journeys
  { journey-id: uint }
  {
    customer-id: (string-ascii 50),
    journey-type: (string-ascii 30),
    status: (string-ascii 20),
    start-time: uint,
    end-time: uint,
    total-milestones: uint,
    completed-milestones: uint,
    mapper: principal
  }
)

(define-map journey-milestones
  { milestone-id: uint }
  {
    journey-id: uint,
    milestone-name: (string-ascii 50),
    touchpoint: (string-ascii 30),
    timestamp: uint,
    value: uint,
    completed: bool
  }
)

(define-map customer-journey-stats
  { customer-id: (string-ascii 50) }
  {
    total-journeys: uint,
    completed-journeys: uint,
    average-completion-time: uint,
    total-rewards: uint
  }
)

;; Public Functions

;; Start a new customer journey
(define-public (start-journey
  (customer-id (string-ascii 50))
  (journey-type (string-ascii 30))
)
  (let
    (
      (journey-id (var-get next-journey-id))
      (current-stats (default-to
        { total-journeys: u0, completed-journeys: u0, average-completion-time: u0, total-rewards: u0 }
        (map-get? customer-journey-stats { customer-id: customer-id })
      ))
    )
    (asserts! (> (len customer-id) u0) err-invalid-data)
    (asserts! (> (len journey-type) u0) err-invalid-data)

    (map-set customer-journeys
      { journey-id: journey-id }
      {
        customer-id: customer-id,
        journey-type: journey-type,
        status: "active",
        start-time: block-height,
        end-time: u0,
        total-milestones: u0,
        completed-milestones: u0,
        mapper: tx-sender
      }
    )

    (map-set customer-journey-stats
      { customer-id: customer-id }
      (merge current-stats { total-journeys: (+ (get total-journeys current-stats) u1) })
    )

    (var-set next-journey-id (+ journey-id u1))
    (ok journey-id)
  )
)

;; Add milestone to journey
(define-public (add-milestone
  (journey-id uint)
  (milestone-name (string-ascii 50))
  (touchpoint (string-ascii 30))
  (value uint)
)
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (journey-data (unwrap! (map-get? customer-journeys { journey-id: journey-id }) err-not-found))
    )
    (asserts! (is-eq (get status journey-data) "active") err-journey-complete)
    (asserts! (> (len milestone-name) u0) err-invalid-data)

    (map-set journey-milestones
      { milestone-id: milestone-id }
      {
        journey-id: journey-id,
        milestone-name: milestone-name,
        touchpoint: touchpoint,
        timestamp: block-height,
        value: value,
        completed: false
      }
    )

    (map-set customer-journeys
      { journey-id: journey-id }
      (merge journey-data { total-milestones: (+ (get total-milestones journey-data) u1) })
    )

    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Complete milestone
(define-public (complete-milestone (milestone-id uint))
  (let
    (
      (milestone-data (unwrap! (map-get? journey-milestones { milestone-id: milestone-id }) err-not-found))
      (journey-data (unwrap! (map-get? customer-journeys { journey-id: (get journey-id milestone-data) }) err-not-found))
    )
    (asserts! (not (get completed milestone-data)) err-invalid-data)

    (map-set journey-milestones
      { milestone-id: milestone-id }
      (merge milestone-data { completed: true })
    )

    (map-set customer-journeys
      { journey-id: (get journey-id milestone-data) }
      (merge journey-data { completed-milestones: (+ (get completed-milestones journey-data) u1) })
    )

    (ok true)
  )
)

;; Complete journey
(define-public (complete-journey (journey-id uint))
  (let
    (
      (journey-data (unwrap! (map-get? customer-journeys { journey-id: journey-id }) err-not-found))
      (customer-stats (unwrap! (map-get? customer-journey-stats { customer-id: (get customer-id journey-data) }) err-not-found))
      (completion-time (- block-height (get start-time journey-data)))
    )
    (asserts! (is-eq (get status journey-data) "active") err-journey-complete)

    (map-set customer-journeys
      { journey-id: journey-id }
      (merge journey-data {
        status: "completed",
        end-time: block-height
      })
    )

    (map-set customer-journey-stats
      { customer-id: (get customer-id journey-data) }
      (merge customer-stats {
        completed-journeys: (+ (get completed-journeys customer-stats) u1),
        total-rewards: (+ (get total-rewards customer-stats) u100)
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get journey by ID
(define-read-only (get-journey (journey-id uint))
  (map-get? customer-journeys { journey-id: journey-id })
)

;; Get milestone by ID
(define-read-only (get-milestone (milestone-id uint))
  (map-get? journey-milestones { milestone-id: milestone-id })
)

;; Get customer journey statistics
(define-read-only (get-customer-journey-stats (customer-id (string-ascii 50)))
  (map-get? customer-journey-stats { customer-id: customer-id })
)

;; Calculate journey completion rate
(define-read-only (get-completion-rate (journey-id uint))
  (match (map-get? customer-journeys { journey-id: journey-id })
    journey-data
    (if (> (get total-milestones journey-data) u0)
      (/ (* (get completed-milestones journey-data) u100) (get total-milestones journey-data))
      u0
    )
    u0
  )
)
