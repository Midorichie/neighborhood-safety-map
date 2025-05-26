;; safety-zones.clar
;; Contract for managing designated safety zones and community resources

;; Error constants
(define-constant ERR_NOT_AUTHORIZED u500)
(define-constant ERR_ZONE_NOT_FOUND u501)
(define-constant ERR_INVALID_COORDINATES u502)
(define-constant ERR_ZONE_ALREADY_EXISTS u503)
(define-constant ERR_INVALID_ZONE_TYPE u504)

;; Zone types
(define-constant ZONE_TYPE_SAFE_HOUSE u1)
(define-constant ZONE_TYPE_POLICE_STATION u2)
(define-constant ZONE_TYPE_HOSPITAL u3)
(define-constant ZONE_TYPE_SCHOOL u4)
(define-constant ZONE_TYPE_COMMUNITY_CENTER u5)

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var next-zone-id uint u1)
(define-data-var zones-paused bool false)

;; Safety zones map
(define-map safety-zones
  {id: uint}
  {name: (buff 128),
   latitude: int,
   longitude: int,
   zone-type: uint,
   radius: uint,
   contact-info: (optional (buff 256)),
   verified: bool,
   created-by: principal,
   created-at: uint})

;; Zone ratings by community members
(define-map zone-ratings
  {zone-id: uint, rater: principal}
  {rating: uint,
   comment: (optional (buff 256)),
   timestamp: uint})

;; Zone statistics
(define-map zone-stats
  {zone-id: uint}
  {total-ratings: uint,
   average-rating: uint,
   incident-count: uint})

;; Emergency pause function
(define-public (pause-zones)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (var-set zones-paused true)
    (ok true)))

(define-public (unpause-zones)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (var-set zones-paused false)
    (ok true)))

;; Add a new safety zone
(define-public (add-safety-zone 
  (name (buff 128))
  (lat int) 
  (lon int) 
  (zone-type uint) 
  (radius uint)
  (contact-info (optional (buff 256))))
  (begin
    (asserts! (not (var-get zones-paused)) (err ERR_NOT_AUTHORIZED))
    
    ;; Validate coordinates
    (asserts! (and (>= lat -90000000) (<= lat 90000000)) (err ERR_INVALID_COORDINATES))
    (asserts! (and (>= lon -180000000) (<= lon 180000000)) (err ERR_INVALID_COORDINATES))
    
    ;; Validate zone type
    (asserts! (and (>= zone-type ZONE_TYPE_SAFE_HOUSE) 
                   (<= zone-type ZONE_TYPE_COMMUNITY_CENTER)) 
              (err ERR_INVALID_ZONE_TYPE))
    
    (let ((zone-id (var-get next-zone-id))
          (current-timestamp (unwrap-panic (get-block-info? time (- block-height u1)))))
      
      ;; Create the zone
      (map-set safety-zones {id: zone-id}
        {name: name,
         latitude: lat,
         longitude: lon,
         zone-type: zone-type,
         radius: radius,
         contact-info: contact-info,
         verified: false,
         created-by: tx-sender,
         created-at: current-timestamp})
      
      ;; Initialize zone stats
      (map-set zone-stats {zone-id: zone-id}
        {total-ratings: u0,
         average-rating: u0,
         incident-count: u0})
      
      (var-set next-zone-id (+ zone-id u1))
      (ok zone-id))))

;; Verify a safety zone
(define-public (verify-zone (zone-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    
    (match (map-get? safety-zones {id: zone-id})
      zone
      (begin
        (map-set safety-zones {id: zone-id}
          (merge zone {verified: true}))
        (ok true))
      (err ERR_ZONE_NOT_FOUND))))

;; Rate a safety zone
(define-public (rate-zone (zone-id uint) (rating uint) (comment (optional (buff 256))))
  (begin
    (asserts! (not (var-get zones-paused)) (err ERR_NOT_AUTHORIZED))
    (asserts! (and (>= rating u1) (<= rating u5)) (err ERR_INVALID_ZONE_TYPE))
    
    (match (map-get? safety-zones {id: zone-id})
      zone
      (let ((current-timestamp (unwrap-panic (get-block-info? time (- block-height u1))))
            (existing-rating (map-get? zone-ratings {zone-id: zone-id, rater: tx-sender}))
            (current-stats (default-to 
                             {total-ratings: u0, average-rating: u0, incident-count: u0}
                             (map-get? zone-stats {zone-id: zone-id}))))
        
        ;; Add or update rating
        (map-set zone-ratings {zone-id: zone-id, rater: tx-sender}
          {rating: rating,
           comment: comment,
           timestamp: current-timestamp})
        
        ;; Update stats only if it's a new rating
        (if (is-none existing-rating)
          (let ((new-total (+ (get total-ratings current-stats) u1))
                (new-average (/ (+ (* (get average-rating current-stats) (get total-ratings current-stats))
                                   (* rating u100))
                                new-total)))
            (map-set zone-stats {zone-id: zone-id}
              (merge current-stats 
                     {total-ratings: new-total, 
                      average-rating: new-average})))
          ;; If updating existing rating, use simplified calculation
          (let ((total (get total-ratings current-stats)))
            (if (> total u0)
              (map-set zone-stats {zone-id: zone-id}
                (merge current-stats {average-rating: (/ (* rating u100) total)}))
              true)))
        
        (ok true))
      (err ERR_ZONE_NOT_FOUND))))

;; Report incident near a zone
(define-public (report-zone-incident (zone-id uint))
  (begin
    (match (map-get? safety-zones {id: zone-id})
      zone
      (let ((current-stats (default-to 
                             {total-ratings: u0, average-rating: u0, incident-count: u0}
                             (map-get? zone-stats {zone-id: zone-id}))))
        (map-set zone-stats {zone-id: zone-id}
          (merge current-stats 
                 {incident-count: (+ (get incident-count current-stats) u1)}))
        (ok true))
      (err ERR_ZONE_NOT_FOUND))))

;; Read-only functions
(define-read-only (get-safety-zone (zone-id uint))
  (match (map-get? safety-zones {id: zone-id})
    zone (ok zone)
    (err ERR_ZONE_NOT_FOUND)))

(define-read-only (get-zone-stats (zone-id uint))
  (ok (default-to 
        {total-ratings: u0, average-rating: u0, incident-count: u0}
        (map-get? zone-stats {zone-id: zone-id}))))

(define-read-only (get-zone-rating (zone-id uint) (rater principal))
  (map-get? zone-ratings {zone-id: zone-id, rater: rater}))

(define-read-only (get-zones-by-type (zone-type uint))
  (ok (var-get next-zone-id)))

(define-read-only (is-zones-paused)
  (var-get zones-paused))

(define-read-only (get-next-zone-id)
  (var-get next-zone-id))
