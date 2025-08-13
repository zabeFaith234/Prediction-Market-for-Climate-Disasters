;; title: prediction-market-climate

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PREDICTION (err u101))
(define-constant ERR_PREDICTION_CLOSED (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_PREDICTION_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_RESOLVED (err u105))
(define-constant ERR_PREDICTION_ACTIVE (err u106))
(define-constant ERR_INVALID_AMOUNT (err u107))
(define-constant ERR_NO_WINNINGS (err u108))

(define-data-var next-prediction-id uint u1)
(define-data-var total-relief-fund uint u0)
(define-data-var relief-fund-percentage uint u10)

(define-map predictions
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    deadline: uint,
    resolution-block: uint,
    total-yes-bets: uint,
    total-no-bets: uint,
    resolved: bool,
    outcome: (optional bool),
    relief-donation: uint,
  }
)

(define-map user-bets
  {
    user: principal,
    prediction-id: uint,
  }
  {
    amount: uint,
    prediction: bool,
    claimed: bool,
  }
)

(define-map user-balances
  principal
  uint
)

(define-map creator-reputation
  principal
  {
    total-predictions: uint,
    correct-predictions: uint,
    accuracy-score: uint,
  }
)

(define-public (create-prediction
    (title (string-ascii 100))
    (description (string-ascii 500))
    (deadline uint)
  )
  (let (
      (prediction-id (var-get next-prediction-id))
      (current-block stacks-block-height)
    )
    (asserts! (> deadline current-block) ERR_INVALID_PREDICTION)
    (asserts! (> (len title) u0) ERR_INVALID_PREDICTION)
    (map-set predictions prediction-id {
      creator: tx-sender,
      title: title,
      description: description,
      deadline: deadline,
      resolution-block: u0,
      total-yes-bets: u0,
      total-no-bets: u0,
      resolved: false,
      outcome: none,
      relief-donation: u0,
    })
    (var-set next-prediction-id (+ prediction-id u1))
    (ok prediction-id)
  )
)

(define-public (place-bet
    (prediction-id uint)
    (amount uint)
    (prediction bool)
  )
  (let (
      (prediction-data (unwrap! (map-get? predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (current-block stacks-block-height)
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (< current-block (get deadline prediction-data))
      ERR_PREDICTION_CLOSED
    )
    (asserts! (not (get resolved prediction-data)) ERR_ALREADY_RESOLVED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (- user-balance amount))
    (map-set user-bets {
      user: tx-sender,
      prediction-id: prediction-id,
    } {
      amount: amount,
      prediction: prediction,
      claimed: false,
    })
    (map-set predictions prediction-id
      (merge prediction-data {
        total-yes-bets: (if prediction
          (+ (get total-yes-bets prediction-data) amount)
          (get total-yes-bets prediction-data)
        ),
        total-no-bets: (if prediction
          (get total-no-bets prediction-data)
          (+ (get total-no-bets prediction-data) amount)
        ),
      })
    )
    (ok true)
  )
)

(define-public (resolve-prediction
    (prediction-id uint)
    (outcome bool)
  )
  (let (
      (prediction-data (unwrap! (map-get? predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (current-block stacks-block-height)
      (total-pool (+ (get total-yes-bets prediction-data) (get total-no-bets prediction-data)))
      (relief-amount (/ (* total-pool (var-get relief-fund-percentage)) u100))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> current-block (get deadline prediction-data))
      ERR_PREDICTION_ACTIVE
    )
    (asserts! (not (get resolved prediction-data)) ERR_ALREADY_RESOLVED)
    (map-set predictions prediction-id
      (merge prediction-data {
        resolved: true,
        outcome: (some outcome),
        resolution-block: current-block,
        relief-donation: relief-amount,
      })
    )
    (var-set total-relief-fund (+ (var-get total-relief-fund) relief-amount))
    (unwrap-panic (update-creator-reputation (get creator prediction-data) outcome))
    (ok true)
  )
)

(define-public (claim-winnings (prediction-id uint))
  (let (
      (prediction-data (unwrap! (map-get? predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (user-bet (unwrap!
        (map-get? user-bets {
          user: tx-sender,
          prediction-id: prediction-id,
        })
        ERR_NO_WINNINGS
      ))
      (outcome (unwrap! (get outcome prediction-data) ERR_PREDICTION_NOT_FOUND))
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
    (asserts! (get resolved prediction-data) ERR_PREDICTION_NOT_FOUND)
    (asserts! (not (get claimed user-bet)) ERR_NO_WINNINGS)
    (asserts! (is-eq (get prediction user-bet) outcome) ERR_NO_WINNINGS)
    (let (
        (total-pool (+ (get total-yes-bets prediction-data)
          (get total-no-bets prediction-data)
        ))
        (winning-pool (if outcome
          (get total-yes-bets prediction-data)
          (get total-no-bets prediction-data)
        ))
        (relief-amount (get relief-donation prediction-data))
        (distributable-amount (- total-pool relief-amount))
        (user-winnings (if (> winning-pool u0)
          (/ (* (get amount user-bet) distributable-amount) winning-pool)
          u0
        ))
      )
      (asserts! (> user-winnings u0) ERR_NO_WINNINGS)
      (map-set user-bets {
        user: tx-sender,
        prediction-id: prediction-id,
      }
        (merge user-bet { claimed: true })
      )
      (map-set user-balances tx-sender (+ user-balance user-winnings))
      (ok user-winnings)
    )
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((user-balance (default-to u0 (map-get? user-balances tx-sender))))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_FUNDS)
    (map-set user-balances tx-sender (- user-balance amount))
    (as-contract (stx-transfer? amount tx-sender (as-contract tx-sender)))
  )
)

(define-public (deposit-funds (amount uint))
  (let ((user-balance (default-to u0 (map-get? user-balances tx-sender))))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (+ user-balance amount))
    (ok true)
  )
)

(define-public (withdraw-relief-funds
    (amount uint)
    (recipient principal)
  )
  (let ((current-relief-fund (var-get total-relief-fund)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-relief-fund amount) ERR_INSUFFICIENT_FUNDS)
    (var-set total-relief-fund (- current-relief-fund amount))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

(define-public (update-relief-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-percentage u50) ERR_INVALID_AMOUNT)
    (var-set relief-fund-percentage new-percentage)
    (ok true)
  )
)

(define-read-only (get-prediction (prediction-id uint))
  (map-get? predictions prediction-id)
)

(define-read-only (get-user-bet
    (user principal)
    (prediction-id uint)
  )
  (map-get? user-bets {
    user: user,
    prediction-id: prediction-id,
  })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-total-relief-fund)
  (var-get total-relief-fund)
)

(define-read-only (get-relief-percentage)
  (var-get relief-fund-percentage)
)

(define-read-only (get-next-prediction-id)
  (var-get next-prediction-id)
)

(define-read-only (get-prediction-stats (prediction-id uint))
  (match (map-get? predictions prediction-id)
    prediction-data (ok {
      total-pool: (+ (get total-yes-bets prediction-data) (get total-no-bets prediction-data)),
      yes-bets: (get total-yes-bets prediction-data),
      no-bets: (get total-no-bets prediction-data),
      resolved: (get resolved prediction-data),
      outcome: (get outcome prediction-data),
      relief-donation: (get relief-donation prediction-data),
    })
    ERR_PREDICTION_NOT_FOUND
  )
)

(define-read-only (calculate-potential-winnings
    (prediction-id uint)
    (amount uint)
    (prediction bool)
  )
  (match (map-get? predictions prediction-id)
    prediction-data (let (
        (total-yes (get total-yes-bets prediction-data))
        (total-no (get total-no-bets prediction-data))
        (total-pool (+ total-yes total-no))
        (relief-amount (/ (* total-pool (var-get relief-fund-percentage)) u100))
        (distributable (- total-pool relief-amount))
        (winning-pool (if prediction
          (+ total-yes amount)
          (+ total-no amount)
        ))
      )
      (if (> winning-pool u0)
        (ok (/ (* amount distributable) winning-pool))
        (ok u0)
      )
    )
    ERR_PREDICTION_NOT_FOUND
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-private (update-creator-reputation (creator principal) (correct-outcome bool))
  (let (
      (current-rep (default-to 
        { total-predictions: u0, correct-predictions: u0, accuracy-score: u0 }
        (map-get? creator-reputation creator)
      ))
      (new-total (+ (get total-predictions current-rep) u1))
      (new-correct (if correct-outcome
        (+ (get correct-predictions current-rep) u1)
        (get correct-predictions current-rep)
      ))
      (new-accuracy (if (> new-total u0)
        (/ (* new-correct u100) new-total)
        u0
      ))
    )
    (map-set creator-reputation creator {
      total-predictions: new-total,
      correct-predictions: new-correct,
      accuracy-score: new-accuracy,
    })
    (ok true)
  )
)

(define-read-only (get-creator-reputation (creator principal))
  (default-to 
    { total-predictions: u0, correct-predictions: u0, accuracy-score: u0 }
    (map-get? creator-reputation creator)
  )
)

(define-read-only (get-prediction-with-reputation (prediction-id uint))
  (match (map-get? predictions prediction-id)
    prediction-data (let (
        (creator-rep (get-creator-reputation (get creator prediction-data)))
      )
      (ok {
        prediction: prediction-data,
        creator-accuracy: (get accuracy-score creator-rep),
        creator-total-predictions: (get total-predictions creator-rep),
      })
    )
    ERR_PREDICTION_NOT_FOUND
  )
)
