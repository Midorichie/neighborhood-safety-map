;; neighborhood-safety-map.clar
;; Enhanced version with bug fixes, security improvements, and new functionality

;; Error constants
(define-constant ERR_INVALID_LATITUDE u100)
(define-constant ERR_INVALID_LONGITUDE u101)
(define-constant ERR_INVALID_SEVERITY u102)
(define-constant ERR_REPORT_NOT_FOUND u200)
(define-constant ERR_NOT_AUTHORIZED u300)
(define-constant ERR_ALREADY_VERIFIED u301)
(define-constant ERR_CANNOT_VERIFY_OWN_REPORT u302)
(define-constant ERR_INVALID_RADIUS u400)

;; Constants
(define-constant MAX_SEVERITY u5)
(define-constant MIN_VERIFICATION_COUNT u3)
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var next-report-id uint u1)
(define-data-var contract-paused bool false)

;; Main reports map
(define-map reports
  {id: uint}
  {latitude: int,
   longitude: int,
   reporter: principal,
   timestamp: uint,
   severity: uint,
   note: (optional (buff 256)),
   verification-count: uint,
   is-verified: bool})

;; Verification tracking - prevents double voting
(define-map verifications
  {report-id: uint, verifier: principal}
  {verified: bool})

;; Reporter reputation system
(define-map reporter-reputation
  {reporter: principal}
  {total-reports: uint,
   verified-reports: uint,
   reputation-score: uint}) ;; 0-100 scale

;; Emergency function - pause contract in case of issues
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (var-set contract-paused false)
    (ok true)))

;; BUG FIX: Fixed the timestamp function and added proper validation
(define-public (add-report (lat int) (lon int) (severity uint) (note (optional (buff 256))))
  (begin
    ;; Security: Check if contract is paused
    (asserts! (not (var-get contract-paused)) (err ERR_NOT_AUTHORIZED))
    
    ;; Validate coordinates (lat: +/-90 degrees, lon: +/-180 degrees scaled by 1e6)
    (asserts! (and (>= lat -90000000) (<= lat 90000000)) (err ERR_INVALID_LATITUDE))
    (asserts! (and (>= lon -180000000) (<= lon 180000000)) (err ERR_INVALID_LONGITUDE))
    (asserts! (and (>= severity u1) (<= severity MAX_SEVERITY)) (err ERR_INVALID_SEVERITY))
    
    (let ((rid (var-get next-report-id))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
      
      ;; Add the report
      (map-set reports {id: rid}
        { latitude: lat,
          longitude: lon,
          reporter: tx-sender,
          timestamp: current-timestamp, ;; BUG FIX: Use proper block timestamp
          severity: severity,
          note: note,
          verification-count: u0,
          is-verified: false })
      
      ;; Update reporter stats
      (update-reporter-stats tx-sender)
      
      (var-set next-report-id (+ rid u1))
      (ok rid))))

;; NEW FUNCTIONALITY: Verify reports by community
(define-public (verify-report (report-id uint))
  (begin
    (asserts! (not (var-get contract-paused)) (err ERR_NOT_AUTHORIZED))
    
    (match (map-get? reports {id: report-id})
      report 
      (begin
        ;; Cannot verify your own report
        (asserts! (not (is-eq tx-sender (get reporter report))) (err ERR_CANNOT_VERIFY_OWN_REPORT))
        
        ;; Check if already verified by this user
        (asserts! (is-none (map-get? verifications {report-id: report-id, verifier: tx-sender})) 
                  (err ERR_ALREADY_VERIFIED))
        
        ;; Add verification
        (map-set verifications {report-id: report-id, verifier: tx-sender} {verified: true})
        
        (let ((new-count (+ (get verification-count report) u1))
              (is-now-verified (>= new-count MIN_VERIFICATION_COUNT)))
          
          ;; Update report with new verification count
          (map-set reports {id: report-id}
            (merge report {verification-count: new-count, is-verified: is-now-verified}))
          
          ;; If report becomes verified, update reporter reputation
          (if (and is-now-verified (not (get is-verified report)))
            (update-verified-report-count (get reporter report))
            true)
          
          (ok new-count)))
      (err ERR_REPORT_NOT_FOUND))))

;; Helper function to update reporter statistics
(define-private (update-reporter-stats (reporter principal))
  (let ((current-stats (default-to 
                         {total-reports: u0, verified-reports: u0, reputation-score: u50}
                         (map-get? reporter-reputation {reporter: reporter}))))
    (map-set reporter-reputation {reporter: reporter}
      (merge current-stats {total-reports: (+ (get total-reports current-stats) u1)}))
    true))

;; Helper function to update verified report count and reputation
(define-private (update-verified-report-count (reporter principal))
  (let ((current-stats (default-to 
                         {total-reports: u0, verified-reports: u0, reputation-score: u50}
                         (map-get? reporter-reputation {reporter: reporter}))))
    (let ((new-verified (+ (get verified-reports current-stats) u1))
          (total (get total-reports current-stats)))
      (let ((new-reputation (if (> total u0) 
                              (if (> (+ u50 (/ (* new-verified u50) total)) u100)
                                  u100
                                  (+ u50 (/ (* new-verified u50) total)))
                              u50)))
        (map-set reporter-reputation {reporter: reporter}
          {total-reports: total, 
           verified-reports: new-verified, 
           reputation-score: new-reputation})))
    true))

;; Read-only functions
(define-read-only (get-report (rid uint))
  (match (map-get? reports {id: rid})
    report (ok report)
    (err ERR_REPORT_NOT_FOUND)))

(define-read-only (get-reporter-reputation (reporter principal))
  (ok (default-to 
        {total-reports: u0, verified-reports: u0, reputation-score: u50}
        (map-get? reporter-reputation {reporter: reporter}))))

(define-read-only (has-verified-report (report-id uint) (verifier principal))
  (is-some (map-get? verifications {report-id: report-id, verifier: verifier})))

(define-read-only (is-contract-paused)
  (var-get contract-paused))

;; NEW FUNCTIONALITY: Get reports within a radius (simplified version)
;; Note: This is a basic implementation. In production, you'd want more sophisticated geo-queries
(define-read-only (get-reports-in-area (center-lat int) (center-lon int) (radius-degrees int))
  (begin
    (asserts! (> radius-degrees 0) (err ERR_INVALID_RADIUS))
    ;; This would need to be implemented with a more complex iteration mechanism
    ;; For now, returning the next report ID as a placeholder for the count of reports
    (ok (var-get next-report-id))))

(define-read-only (get-next-report-id)
  (var-get next-report-id))
