;; neighborhood-safety-map.clar

(define-map reports
  ((id uint))
  ((latitude int)
   (longitude int)
   (reporter principal)
   (timestamp uint)
   (severity uint)
   (note (optional (buff 256)))))

(define-data-var next-report-id uint u1)
(define-constant max-severity u5)

(define-public (add-report lat lon severity note)
  (begin
    ;; validate coords (lat: ±90°, lon: ±180° scaled by 1e6)
    (asserts! (and (>= lat -90000000) (<= lat 90000000)) (err u100))
    (asserts! (and (>= lon -180000000) (<= lon 180000000)) (err u101))
    (asserts! (<= severity max-severity) (err u102))
    (let ((rid (var-get next-report-id)))
      (map-set reports {id: rid}
        { latitude: lat
         , longitude: lon
         , reporter: tx-sender
         , timestamp: (as-exp unix-epoch)
         , severity: severity
         , note: note })
      (var-set next-report-id (+ rid u1))
      (ok rid))))

(define-read-only (get-report rid)
  (match (map-get? reports {id: rid})
    report (ok report)
    (err u200)))
