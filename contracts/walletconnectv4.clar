;; walletconnectv4.clar
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var total-tipped uint u0)

(define-constant ERR_NOT_OWNER (err u200))
(define-constant ERR_PAUSED (err u201))

(define-public (set-paused (value bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set paused value)
    (ok value)
  )
)

(define-public (send-tip (recipient principal) (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (try! (stx-transfer? amount tx-sender recipient))
    (var-set total-tipped (+ (var-get total-tipped) amount))
    (ok amount)
  )
)

(define-read-only (get-stats)
  (ok {
    owner: (var-get contract-owner),
    paused: (var-get paused),
    total: (var-get total-tipped)
  })
)
