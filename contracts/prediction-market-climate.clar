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
(define-constant ERR_INVALID_STAGE (err u109))
(define-constant ERR_TOO_MANY_STAGES (err u110))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u111))
(define-constant ERR_NO_LIQUIDITY_POSITION (err u112))
(define-constant ERR_CONTRACT_PAUSED (err u113))
(define-constant MAX_STAGES u5)
(define-constant LIQUIDITY_FEE_PERCENTAGE u2)

(define-data-var next-prediction-id uint u1)
(define-data-var next-multi-stage-id uint u1)
(define-data-var total-relief-fund uint u0)
(define-data-var relief-fund-percentage uint u10)
(define-data-var total-liquidity-pool uint u0)
(define-data-var total-liquidity-shares uint u0)
(define-data-var contract-paused bool false)
(define-data-var pause-reason (string-ascii 100) "")

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

(define-map multi-stage-predictions
  uint
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    deadline: uint,
    resolution-block: uint,
    stage-labels: (list 5 (string-ascii 50)),
    stage-bets: (list 5 uint),
    resolved: bool,
    winning-stage: (optional uint),
    relief-donation: uint,
  }
)

(define-map multi-stage-user-bets
  {
    user: principal,
    prediction-id: uint,
  }
  {
    amount: uint,
    chosen-stage: uint,
    claimed: bool,
  }
)

(define-map liquidity-providers
  principal
  {
    shares: uint,
    total-provided: uint,
    fees-earned: uint,
  }
)

(define-public (pause-contract (reason (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (var-set pause-reason reason)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused false)
    (var-set pause-reason "")
    (ok true)
  )
)

(define-read-only (is-contract-paused)
  (ok {
    paused: (var-get contract-paused),
    reason: (var-get pause-reason),
  })
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
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
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

(define-public (create-multi-stage-prediction
    (title (string-ascii 100))
    (description (string-ascii 500))
    (deadline uint)
    (stage-labels (list 5 (string-ascii 50)))
  )
  (let (
      (prediction-id (var-get next-multi-stage-id))
      (current-block stacks-block-height)
      (stage-count (len stage-labels))
    )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (> deadline current-block) ERR_INVALID_PREDICTION)
    (asserts! (> (len title) u0) ERR_INVALID_PREDICTION)
    (asserts! (and (>= stage-count u2) (<= stage-count MAX_STAGES)) ERR_TOO_MANY_STAGES)
    (map-set multi-stage-predictions prediction-id {
      creator: tx-sender,
      title: title,
      description: description,
      deadline: deadline,
      resolution-block: u0,
      stage-labels: stage-labels,
      stage-bets: (list u0 u0 u0 u0 u0),
      resolved: false,
      winning-stage: none,
      relief-donation: u0,
    })
    (var-set next-multi-stage-id (+ prediction-id u1))
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
      (liquidity-fee (/ (* amount LIQUIDITY_FEE_PERCENTAGE) u100))
      (net-bet-amount (- amount liquidity-fee))
    )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
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
      amount: net-bet-amount,
      prediction: prediction,
      claimed: false,
    })
    (map-set predictions prediction-id
      (merge prediction-data {
        total-yes-bets: (if prediction
          (+ (get total-yes-bets prediction-data) net-bet-amount)
          (get total-yes-bets prediction-data)
        ),
        total-no-bets: (if prediction
          (get total-no-bets prediction-data)
          (+ (get total-no-bets prediction-data) net-bet-amount)
        ),
      })
    )
    (unwrap-panic (distribute-liquidity-fees liquidity-fee))
    (ok true)
  )
)

(define-public (place-multi-stage-bet
    (prediction-id uint)
    (amount uint)
    (chosen-stage uint)
  )
  (let (
      (prediction-data (unwrap! (map-get? multi-stage-predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (current-block stacks-block-height)
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
      (stage-count (len (get stage-labels prediction-data)))
      (liquidity-fee (/ (* amount LIQUIDITY_FEE_PERCENTAGE) u100))
      (net-bet-amount (- amount liquidity-fee))
    )
    (asserts! (not (var-get contract-paused)) ERR_CONTRACT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (< current-block (get deadline prediction-data)) ERR_PREDICTION_CLOSED)
    (asserts! (not (get resolved prediction-data)) ERR_ALREADY_RESOLVED)
    (asserts! (< chosen-stage stage-count) ERR_INVALID_STAGE)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (- user-balance amount))
    (map-set multi-stage-user-bets {
      user: tx-sender,
      prediction-id: prediction-id,
    } {
      amount: net-bet-amount,
      chosen-stage: chosen-stage,
      claimed: false,
    })
    (map-set multi-stage-predictions prediction-id
      (merge prediction-data {
        stage-bets: (unwrap-panic (update-stage-bets (get stage-bets prediction-data) chosen-stage net-bet-amount)),
      })
    )
    (unwrap-panic (distribute-liquidity-fees liquidity-fee))
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

(define-public (resolve-multi-stage-prediction
    (prediction-id uint)
    (winning-stage uint)
  )
  (let (
      (prediction-data (unwrap! (map-get? multi-stage-predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (current-block stacks-block-height)
      (stage-count (len (get stage-labels prediction-data)))
      (total-pool (fold + (get stage-bets prediction-data) u0))
      (relief-amount (/ (* total-pool (var-get relief-fund-percentage)) u100))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> current-block (get deadline prediction-data)) ERR_PREDICTION_ACTIVE)
    (asserts! (not (get resolved prediction-data)) ERR_ALREADY_RESOLVED)
    (asserts! (< winning-stage stage-count) ERR_INVALID_STAGE)
    (map-set multi-stage-predictions prediction-id
      (merge prediction-data {
        resolved: true,
        winning-stage: (some winning-stage),
        resolution-block: current-block,
        relief-donation: relief-amount,
      })
    )
    (var-set total-relief-fund (+ (var-get total-relief-fund) relief-amount))
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

(define-public (claim-multi-stage-winnings (prediction-id uint))
  (let (
      (prediction-data (unwrap! (map-get? multi-stage-predictions prediction-id) ERR_PREDICTION_NOT_FOUND))
      (user-bet (unwrap!
        (map-get? multi-stage-user-bets {
          user: tx-sender,
          prediction-id: prediction-id,
        })
        ERR_NO_WINNINGS
      ))
      (winning-stage (unwrap! (get winning-stage prediction-data) ERR_PREDICTION_NOT_FOUND))
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
    )
    (asserts! (get resolved prediction-data) ERR_PREDICTION_NOT_FOUND)
    (asserts! (not (get claimed user-bet)) ERR_NO_WINNINGS)
    (asserts! (is-eq (get chosen-stage user-bet) winning-stage) ERR_NO_WINNINGS)
    (let (
        (total-pool (fold + (get stage-bets prediction-data) u0))
        (winning-pool (default-to u0 (element-at? (get stage-bets prediction-data) winning-stage)))
        (relief-amount (get relief-donation prediction-data))
        (distributable-amount (- total-pool relief-amount))
        (user-winnings (if (> winning-pool u0)
          (/ (* (get amount user-bet) distributable-amount) winning-pool)
          u0
        ))
      )
      (asserts! (> user-winnings u0) ERR_NO_WINNINGS)
      (map-set multi-stage-user-bets {
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

(define-public (provide-liquidity (amount uint))
  (let (
      (current-pool (var-get total-liquidity-pool))
      (current-shares (var-get total-liquidity-shares))
      (provider-data (default-to 
        { shares: u0, total-provided: u0, fees-earned: u0 }
        (map-get? liquidity-providers tx-sender)
      ))
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
      (new-shares (if (is-eq current-pool u0)
        amount
        (/ (* amount current-shares) current-pool)
      ))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-balances tx-sender (- user-balance amount))
    (var-set total-liquidity-pool (+ current-pool amount))
    (var-set total-liquidity-shares (+ current-shares new-shares))
    (map-set liquidity-providers tx-sender {
      shares: (+ (get shares provider-data) new-shares),
      total-provided: (+ (get total-provided provider-data) amount),
      fees-earned: (get fees-earned provider-data),
    })
    (ok new-shares)
  )
)

(define-public (withdraw-liquidity (shares uint))
  (let (
      (current-pool (var-get total-liquidity-pool))
      (current-shares (var-get total-liquidity-shares))
      (provider-data (unwrap! (map-get? liquidity-providers tx-sender) ERR_NO_LIQUIDITY_POSITION))
      (user-balance (default-to u0 (map-get? user-balances tx-sender)))
      (withdrawal-amount (if (> current-shares u0)
        (/ (* shares current-pool) current-shares)
        u0
      ))
    )
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get shares provider-data) shares) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (>= current-pool withdrawal-amount) ERR_INSUFFICIENT_LIQUIDITY)
    (var-set total-liquidity-pool (- current-pool withdrawal-amount))
    (var-set total-liquidity-shares (- current-shares shares))
    (map-set liquidity-providers tx-sender {
      shares: (- (get shares provider-data) shares),
      total-provided: (get total-provided provider-data),
      fees-earned: (get fees-earned provider-data),
    })
    (map-set user-balances tx-sender (+ user-balance withdrawal-amount))
    (ok withdrawal-amount)
  )
)

(define-private (distribute-liquidity-fees (fee-amount uint))
  (let (
      (current-pool (var-get total-liquidity-pool))
      (current-shares (var-get total-liquidity-shares))
    )
    (if (> current-shares u0)
      (begin
        (var-set total-liquidity-pool (+ current-pool fee-amount))
        (ok true)
      )
      (ok true)
    )
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

(define-private (update-stage-bets (current-bets (list 5 uint)) (stage-index uint) (amount uint))
  (let ((stage-0 (default-to u0 (element-at? current-bets u0)))
        (stage-1 (default-to u0 (element-at? current-bets u1)))
        (stage-2 (default-to u0 (element-at? current-bets u2)))
        (stage-3 (default-to u0 (element-at? current-bets u3)))
        (stage-4 (default-to u0 (element-at? current-bets u4))))
    (ok (list 
      (if (is-eq stage-index u0) (+ stage-0 amount) stage-0)
      (if (is-eq stage-index u1) (+ stage-1 amount) stage-1)
      (if (is-eq stage-index u2) (+ stage-2 amount) stage-2)
      (if (is-eq stage-index u3) (+ stage-3 amount) stage-3)
      (if (is-eq stage-index u4) (+ stage-4 amount) stage-4)
    ))
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

(define-read-only (get-multi-stage-prediction (prediction-id uint))
  (map-get? multi-stage-predictions prediction-id)
)

(define-read-only (get-multi-stage-user-bet
    (user principal)
    (prediction-id uint)
  )
  (map-get? multi-stage-user-bets {
    user: user,
    prediction-id: prediction-id,
  })
)

(define-read-only (get-multi-stage-prediction-stats (prediction-id uint))
  (match (map-get? multi-stage-predictions prediction-id)
    prediction-data (ok {
      total-pool: (fold + (get stage-bets prediction-data) u0),
      stage-bets: (get stage-bets prediction-data),
      stage-labels: (get stage-labels prediction-data),
      resolved: (get resolved prediction-data),
      winning-stage: (get winning-stage prediction-data),
      relief-donation: (get relief-donation prediction-data),
    })
    ERR_PREDICTION_NOT_FOUND
  )
)

(define-read-only (calculate-multi-stage-potential-winnings
    (prediction-id uint)
    (amount uint)
    (chosen-stage uint)
  )
  (match (map-get? multi-stage-predictions prediction-id)
    prediction-data (let (
        (current-stage-bets (get stage-bets prediction-data))
        (current-stage-amount (default-to u0 (element-at? current-stage-bets chosen-stage)))
        (total-pool (fold + current-stage-bets u0))
        (relief-amount (/ (* (+ total-pool amount) (var-get relief-fund-percentage)) u100))
        (distributable (- (+ total-pool amount) relief-amount))
        (winning-pool (+ current-stage-amount amount))
      )
      (if (> winning-pool u0)
        (ok (/ (* amount distributable) winning-pool))
        (ok u0)
      )
    )
    ERR_PREDICTION_NOT_FOUND
  )
)

(define-read-only (get-next-multi-stage-id)
  (var-get next-multi-stage-id)
)

(define-read-only (get-liquidity-pool-stats)
  (ok {
    total-pool: (var-get total-liquidity-pool),
    total-shares: (var-get total-liquidity-shares),
  })
)

(define-read-only (get-liquidity-provider-info (provider principal))
  (ok (default-to 
    { shares: u0, total-provided: u0, fees-earned: u0 }
    (map-get? liquidity-providers provider)
  ))
)

(define-read-only (calculate-liquidity-value (shares uint))
  (let (
      (current-pool (var-get total-liquidity-pool))
      (current-shares (var-get total-liquidity-shares))
    )
    (if (> current-shares u0)
      (ok (/ (* shares current-pool) current-shares))
      (ok u0)
    )
  )
)
