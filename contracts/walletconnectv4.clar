;; --------------------------------------------------
;; Level 3 — WalletConnect Tips with Authorization
;; --------------------------------------------------

;; Owner & control
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)

;; Global stats
(define-data-var total-tipped uint u0)
(define-data-var total-transactions uint u0)

;; Maps
(define-map tips-by-recipient principal uint)
(define-map tips-by-sender principal uint)
(define-map tx-count-by-sender principal uint)

;; Optional on-chain message
(define-data-var public-note (string-utf8 140) "")

;; Error codes
(define-constant ERR_NOT_OWNER (err u200))
(define-constant ERR_PAUSED (err u201))
(define-constant ERR_INVALID_AMOUNT (err u100))
(define-constant ERR_TRANSFER_FAILED (err u101))

;; ----------------------------------
;; Internal authorization helpers
;; ----------------------------------

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; ----------------------------------
;; Admin: pause / unpause contract
;; ----------------------------------

(define-public (set-paused (value bool))
  (begin
    ;; Verificación de seguridad
    (asserts! (is-owner) ERR_NOT_OWNER)
    
    (var-set paused value)
    (print {
      event: "paused_updated",
      by: tx-sender,
      paused: value
    })
    (ok value)
  )
)

;; ----------------------------------
;; Public: send STX tip (controlled)
;; ----------------------------------

(define-public (send-tip (recipient principal) (amount uint))
  (let
    (
      ;; Pre-cálculo de nuevos valores para los mapas
      (current-recipient-total (default-to u0 (map-get? tips-by-recipient recipient)))
      (current-sender-total (default-to u0 (map-get? tips-by-sender tx-sender)))
      (current-sender-count (default-to u0 (map-get? tx-count-by-sender tx-sender)))
    )
    ;; 1. Guards (Seguridad)
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; 2. Operación principal: Transferencia de STX
    ;; Usamos unwrap! para manejar el resultado de la transferencia directamente
    (unwrap! (stx-transfer? amount tx-sender recipient) ERR_TRANSFER_FAILED)

    ;; 3. Actualización de estado (solo ocurre si la transferencia fue exitosa)
    (var-set total-tipped (+ (var-get total-tipped) amount))
    (var-set total-transactions (+ (var-get total-transactions) u1))

    (map-set tips-by-recipient recipient (+ current-recipient-total amount))
    (map-set tips-by-sender tx-sender (+ current-sender-total amount))
    (map-set tx-count-by-sender tx-sender (+ current-sender-count u1))

    (print {
      event: "tip_sent",
      from: tx-sender,
      to: recipient,
      amount: amount
    })

    (ok amount)
  )
)

;; ----------------------------------
;; Extra public function (non-financial)
;; ----------------------------------

(define-public (set-note (note (string-utf8 140)))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (var-set public-note note)

    (print {
      event: "note_updated",
      by: tx-sender,
      note: note
    })

    (ok true)
  )
)

;; ----------------------------------
;; Read-only views
;; ----------------------------------

(define-read-only (get-note) (var-get public-note))
(define-read-only (get-owner) (ok (var-get contract-owner)))
(define-read-only (is-paused) (ok (var-get paused)))
(define-read-only (get-total-tipped) (ok (var-get total-tipped)))
(define-read-only (get-total-transactions) (ok (var-get total-transactions)))

(define-read-only (get-tips-sent-by (sender principal))
  (ok (default-to u0 (map-get? tips-by-sender sender)))
)

(define-read-only (get-tips-received-by (recipient principal))
  (ok (default-to u0 (map-get? tips-by-recipient recipient)))
)
