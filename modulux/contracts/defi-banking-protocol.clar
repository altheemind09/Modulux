;; Modular AMM Components
;; Component-based modular design

;; System Administration
(define-constant sys-admin tx-sender)

;; Error Code System
(define-constant err-sys-unauthorized (err u700))
(define-constant err-sys-depleted (err u701))
(define-constant err-sys-invalid-input (err u702))
(define-constant err-sys-tolerance (err u703))
(define-constant err-sys-component-mismatch (err u704))
(define-constant err-sys-execution-error (err u705))
(define-constant err-sys-already-active (err u706))
(define-constant err-sys-not-active (err u707))

;; Component State Modules
(define-data-var component-a-reserve uint u0)
(define-data-var component-b-reserve uint u0)
(define-data-var component-shares uint u0)
(define-data-var system-status bool false)

;; Component B Interface Reference
(define-data-var component-b-interface principal .token)

;; Share Distribution Module
(define-map share-distribution principal uint)

;; Activity Logger Module
(define-map activity-log 
  { activity-id: uint }
  { 
    actor: principal,
    component-a-flow-in: uint,
    component-b-flow-out: uint,
    component-a-flow-out: uint,
    component-b-flow-in: uint,
    log-height: uint
  }
)

(define-data-var activity-id-counter uint u0)

;; Component Interface Protocol
(define-trait component-interface
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Utility Module Functions

;; Minimum Selection Function
(define-private (select-min (val-a uint) (val-b uint))
  (if (< val-a val-b) val-a val-b))

;; State Query Module

(define-read-only (query-component-reserves)
  {
    component-a: (var-get component-a-reserve),
    component-b: (var-get component-b-reserve)
  }
)

(define-read-only (query-share-balance (holder principal))
  (default-to u0 (map-get? share-distribution holder))
)

(define-read-only (query-total-shares)
  (var-get component-shares)
)

(define-read-only (query-system-status)
  (var-get system-status)
)

(define-read-only (query-component-b-interface)
  (var-get component-b-interface)
)

;; Calculation Engine Module (0.3% system fee)
(define-read-only (calculate-output-flow (input-flow uint) (input-component uint) (output-component uint))
  (if (or (is-eq input-flow u0) (is-eq input-component u0) (is-eq output-component u0))
    u0
    (let (
      (adjusted-flow (* input-flow u997))
      (flow-numerator (* adjusted-flow output-component))
      (flow-denominator (+ (* input-component u1000) adjusted-flow))
    )
    (/ flow-numerator flow-denominator)))
)

(define-read-only (calculate-input-requirement (output-flow uint) (input-component uint) (output-component uint))
  (if (or (is-eq output-flow u0) (is-eq input-component u0) (is-eq output-component u0))
    u0
    (let (
      (requirement-numerator (* (* input-component output-flow) u1000))
      (requirement-denominator (* (- output-component output-flow) u997))
    )
    (+ (/ requirement-numerator requirement-denominator) u1)))
)

(define-read-only (calculate-proportional-share (component-amount uint) (component-reserve uint) (paired-reserve uint))
  (if (is-eq component-reserve u0)
    u0
    (/ (* component-amount paired-reserve) component-reserve))
)

;; System Lifecycle Module

(define-public (initialize-system (interface <component-interface>) (component-a-init uint) (component-b-init uint))
  (let (
    (initial-share-allocation (select-min component-a-init component-b-init))
  )
    (asserts! (not (var-get system-status)) err-sys-already-active)
    (asserts! (> component-a-init u0) err-sys-invalid-input)
    (asserts! (> component-b-init u0) err-sys-invalid-input)
    (asserts! (> initial-share-allocation u0) err-sys-depleted)
    
    (var-set component-b-interface (contract-of interface))
    
    (try! (contract-call? interface transfer component-b-init tx-sender (as-contract tx-sender) none))
    
    (var-set component-a-reserve component-a-init)
    (var-set component-b-reserve component-b-init)
    (var-set component-shares initial-share-allocation)
    (var-set system-status true)
    
    (map-set share-distribution tx-sender initial-share-allocation)
    
    (ok initial-share-allocation)
  )
)

(define-public (extend-system (interface <component-interface>) (component-a-amount uint) (component-b-amount uint) (min-share-allocation uint))
  (let (
    (current-component-a (var-get component-a-reserve))
    (current-component-b (var-get component-b-reserve))
    (current-share-total (var-get component-shares))
    (new-share-allocation (select-min 
                           (/ (* component-a-amount current-share-total) current-component-a)
                           (/ (* component-b-amount current-share-total) current-component-b)))
    (current-holder-shares (query-share-balance tx-sender))
  )
    (asserts! (var-get system-status) err-sys-not-active)
    (asserts! (is-eq (contract-of interface) (var-get component-b-interface)) err-sys-component-mismatch)
    (asserts! (> component-a-amount u0) err-sys-invalid-input)
    (asserts! (> component-b-amount u0) err-sys-invalid-input)
    (asserts! (>= new-share-allocation min-share-allocation) err-sys-tolerance)
    
    (try! (contract-call? interface transfer component-b-amount tx-sender (as-contract tx-sender) none))
    
    (var-set component-a-reserve (+ current-component-a component-a-amount))
    (var-set component-b-reserve (+ current-component-b component-b-amount))
    (var-set component-shares (+ current-share-total new-share-allocation))
    
    (map-set share-distribution tx-sender (+ current-holder-shares new-share-allocation))
    
    (ok new-share-allocation)
  )
)

(define-public (contract-system (interface <component-interface>) (share-allocation uint) (min-component-a uint) (min-component-b uint))
  (let (
    (current-component-a (var-get component-a-reserve))
    (current-component-b (var-get component-b-reserve))
    (current-share-total (var-get component-shares))
    (current-holder-shares (query-share-balance tx-sender))
    (component-a-withdrawal (/ (* share-allocation current-component-a) current-share-total))
    (component-b-withdrawal (/ (* share-allocation current-component-b) current-share-total))
  )
    (asserts! (var-get system-status) err-sys-not-active)
    (asserts! (is-eq (contract-of interface) (var-get component-b-interface)) err-sys-component-mismatch)
    (asserts! (> share-allocation u0) err-sys-invalid-input)
    (asserts! (>= current-holder-shares share-allocation) err-sys-depleted)
    (asserts! (>= component-a-withdrawal min-component-a) err-sys-tolerance)
    (asserts! (>= component-b-withdrawal min-component-b) err-sys-tolerance)
    
    (var-set component-a-reserve (- current-component-a component-a-withdrawal))
    (var-set component-b-reserve (- current-component-b component-b-withdrawal))
    (var-set component-shares (- current-share-total share-allocation))
    
    (map-set share-distribution tx-sender (- current-holder-shares share-allocation))
    
    (try! (as-contract (stx-transfer? component-a-withdrawal tx-sender tx-sender)))
    (try! (as-contract (contract-call? interface transfer component-b-withdrawal tx-sender tx-sender none)))
    
    (ok { component-a: component-a-withdrawal, component-b: component-b-withdrawal })
  )
)

(define-public (process-a-to-b-flow (interface <component-interface>) (component-a-input uint) (min-component-b-output uint))
  (let (
    (current-component-a (var-get component-a-reserve))
    (current-component-b (var-get component-b-reserve))
    (component-b-output (calculate-output-flow component-a-input current-component-a current-component-b))
    (activity-id (var-get activity-id-counter))
  )
    (asserts! (var-get system-status) err-sys-not-active)
    (asserts! (is-eq (contract-of interface) (var-get component-b-interface)) err-sys-component-mismatch)
    (asserts! (> component-a-input u0) err-sys-invalid-input)
    (asserts! (>= component-b-output min-component-b-output) err-sys-tolerance)
    (asserts! (< component-b-output current-component-b) err-sys-depleted)
    
    (var-set component-a-reserve (+ current-component-a component-a-input))
    (var-set component-b-reserve (- current-component-b component-b-output))
    
    (try! (as-contract (contract-call? interface transfer component-b-output tx-sender tx-sender none)))
    
    (map-set activity-log 
      { activity-id: activity-id }
      { 
        actor: tx-sender,
        component-a-flow-in: component-a-input,
        component-b-flow-out: component-b-output,
        component-a-flow-out: u0,
        component-b-flow-in: u0,
        log-height: block-height
      }
    )
    (var-set activity-id-counter (+ activity-id u1))
    
    (ok component-b-output)
  )
)

(define-public (process-b-to-a-flow (interface <component-interface>) (component-b-input uint) (min-component-a-output uint))
  (let (
    (current-component-a (var-get component-a-reserve))
    (current-component-b (var-get component-b-reserve))
    (component-a-output (calculate-output-flow component-b-input current-component-b current-component-a))
    (activity-id (var-get activity-id-counter))
  )
    (asserts! (var-get system-status) err-sys-not-active)
    (asserts! (is-eq (contract-of interface) (var-get component-b-interface)) err-sys-component-mismatch)
    (asserts! (> component-b-input u0) err-sys-invalid-input)
    (asserts! (>= component-a-output min-component-a-output) err-sys-tolerance)
    (asserts! (< component-a-output current-component-a) err-sys-depleted)
    
    (try! (contract-call? interface transfer component-b-input tx-sender (as-contract tx-sender) none))
    
    (var-set component-a-reserve (- current-component-a component-a-output))
    (var-set component-b-reserve (+ current-component-b component-b-input))
    
    (try! (as-contract (stx-transfer? component-a-output tx-sender tx-sender)))
    
    (map-set activity-log 
      { activity-id: activity-id }
      { 
        actor: tx-sender,
        component-a-flow-in: u0,
        component-b-flow-out: u0,
        component-a-flow-out: component-a-output,
        component-b-flow-in: component-b-input,
        log-height: block-height
      }
    )
    (var-set activity-id-counter (+ activity-id u1))
    
    (ok component-a-output)
  )
)