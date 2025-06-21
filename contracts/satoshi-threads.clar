;; SatoshiThreads - Decentralized Social Identity + Monetization Protocol
;; Summary:
;; A secure and modular smart contract enabling on-chain identities, content creation, 
;; peer-to-peer tipping, and community-governed social networks on the Stacks Layer 2, 
;; secured by Bitcoin finality.

;; Description:
;; SatoshiThreads is a decentralized social infrastructure protocol, purpose-built for 
;; Bitcoin-aligned ecosystems. It provides primitives for user identities, reputation scores, 
;; content publishing, micro-monetization through STX tips, and tokenized communities with 
;; native governance capabilities. Leveraging Clarity and Stacks, it ensures trustless 
;; verification, censorship resistance, and full composability for dApps and open social apps.

;; Features:
;; - On-chain user profiles with unique handles
;; - Tip-based monetization model with protocol fee mechanics
;; - Verifiable engagement tracking and reputation incentives
;; - Decentralized community tokens and member governance
;; - Follower graph tracking for social relationships
;; - Fully Bitcoin-secured via Stacks finality

;; CONSTANTS

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_INVALID_PARAMS (err u105))
(define-constant ERR_PROFILE_NOT_FOUND (err u106))
(define-constant ERR_CONTENT_NOT_FOUND (err u107))
(define-constant ERR_ALREADY_TIPPED (err u108))
(define-constant ERR_SELF_TIP (err u109))
(define-constant ERR_COMMUNITY_EXISTS (err u110))
(define-constant ERR_INVALID_URL (err u111))
(define-constant ERR_INVALID_MESSAGE (err u112))

;; Protocol configuration
(define-constant PROTOCOL_FEE_BPS u250) ;; 2.5% protocol fee
(define-constant MIN_TIP_AMOUNT u1000) ;; Minimum tip in microSTX
(define-constant MAX_HANDLE_LENGTH u32)
(define-constant MAX_BIO_LENGTH u256)
(define-constant MAX_CONTENT_LENGTH u1024)
(define-constant MAX_URL_LENGTH u256)
(define-constant MAX_MESSAGE_LENGTH u256)
(define-constant INITIAL_REPUTATION u100)

;; DATA VARIABLES

(define-data-var protocol-fee-recipient principal CONTRACT_OWNER)
(define-data-var next-profile-id uint u1)
(define-data-var next-content-id uint u1)
(define-data-var next-community-id uint u1)
(define-data-var protocol-paused bool false)

;; DATA MAPS

;; User profiles stored as on-chain identity
(define-map user-profiles
  { profile-id: uint }
  {
    owner: principal,
    handle: (string-ascii 32),
    bio: (string-utf8 256),
    avatar-url: (optional (string-ascii 256)),
    reputation-score: uint,
    total-tips-received: uint,
    total-tips-sent: uint,
    content-count: uint,
    follower-count: uint,
    following-count: uint,
    created-at: uint,
    verified: bool
  }
)

;; Handle to profile ID mapping for unique handles
(define-map handle-to-profile (string-ascii 32) uint)

;; Principal to profile ID mapping
(define-map principal-to-profile principal uint)

;; Content posts with engagement metrics
(define-map content-posts
  { content-id: uint }
  {
    author-id: uint,
    content-text: (string-utf8 1024),
    content-type: (string-ascii 5), ;; "text", "image", "video", etc.
    media-url: (optional (string-ascii 256)),
    tip-count: uint,
    total-tips: uint,
    engagement-score: uint,
    created-at: uint,
    community-id: (optional uint)
  }
)

;; Tip records for content monetization
(define-map content-tips
  { content-id: uint, tipper: principal }
  {
    amount: uint,
    message: (optional (string-utf8 256)),
    tipped-at: uint
  }
)

;; Social connections (following/followers)
(define-map social-connections
  { follower-id: uint, following-id: uint }
  { connected-at: uint }
)

;; Community governance tokens
(define-map communities
  { community-id: uint }
  {
    name: (string-ascii 64),
    description: (string-utf8 256),
    creator-id: uint,
    token-symbol: (string-ascii 8),
    total-supply: uint,
    member-count: uint,
    created-at: uint,
    governance-threshold: uint
  }
)

;; Community membership and token balances
(define-map community-members
  { community-id: uint, member-id: uint }
  {
    token-balance: uint,
    joined-at: uint,
    is-moderator: bool
  }
)

;; Engagement tracking for reputation
(define-map user-engagement
  { profile-id: uint, period: uint } ;; period = stacks-block-height / 2016 (weekly)
  {
    tips-received: uint,
    tips-sent: uint,
    content-posted: uint,
    engagement-score: uint
  }
)

;; PRIVATE FUNCTIONS

(define-private (is-valid-handle (handle (string-ascii 32)))
  (and 
    (> (len handle) u0)
    (<= (len handle) MAX_HANDLE_LENGTH)
    (is-none (map-get? handle-to-profile handle))
  )
)

(define-private (is-valid-url (url (string-ascii 256)))
  (and
    (> (len url) u0)
    (<= (len url) MAX_URL_LENGTH)
    ;; Basic URL validation - starts with http:// or https://
    (or
      (is-eq (unwrap-panic (slice? url u0 u7)) "http://")
      (is-eq (unwrap-panic (slice? url u0 u8)) "https://")
    )
  )
)

(define-private (is-valid-optional-url (url (optional (string-ascii 256))))
  (match url
    some-url (is-valid-url some-url)
    true ;; None is valid
  )
)

(define-private (is-valid-message (message (optional (string-utf8 256))))
  (match message
    some-msg (<= (len some-msg) MAX_MESSAGE_LENGTH)
    true ;; None is valid
  )
)

(define-private (is-valid-content-type (content-type (string-ascii 5)))
  (let ((valid-types (list "text" "image" "video" "audio" "link")))
    (is-some (index-of valid-types content-type))
  )
)

(define-private (calculate-protocol-fee (amount uint))
  (/ (* amount PROTOCOL_FEE_BPS) u10000)
)

(define-private (get-current-period)
  (/ stacks-block-height u2016) ;; Weekly periods
)

(define-private (update-reputation (profile-id uint) (points uint))
  (let ((profile (unwrap! (map-get? user-profiles { profile-id: profile-id }) false)))
    (map-set user-profiles
      { profile-id: profile-id }
      (merge profile { reputation-score: (+ (get reputation-score profile) points) })
    )
    true
  )
)

(define-private (update-engagement (profile-id uint) (tips-received uint) (tips-sent uint) (content-posted uint))
  (let 
    (
      (period (get-current-period))
      (current-engagement (default-to 
        { tips-received: u0, tips-sent: u0, content-posted: u0, engagement-score: u0 }
        (map-get? user-engagement { profile-id: profile-id, period: period })
      ))
    )
    (map-set user-engagement
      { profile-id: profile-id, period: period }
      {
        tips-received: (+ (get tips-received current-engagement) tips-received),
        tips-sent: (+ (get tips-sent current-engagement) tips-sent),
        content-posted: (+ (get content-posted current-engagement) content-posted),
        engagement-score: (+ (get engagement-score current-engagement) tips-received tips-sent content-posted)
      }
    )
  )
)

;; PUBLIC FUNCTIONS - PROFILE MANAGEMENT

;; Create a new user profile (on-chain identity)
(define-public (create-profile (handle (string-ascii 32)) (bio (string-utf8 256)) (avatar-url (optional (string-ascii 256))))
  (let
    (
      (profile-id (var-get next-profile-id))
      (caller tx-sender)
      (validated-avatar-url (if (is-valid-optional-url avatar-url) avatar-url none))
    )
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? principal-to-profile caller)) ERR_ALREADY_EXISTS)
    (asserts! (is-valid-handle handle) ERR_INVALID_PARAMS)
    (asserts! (<= (len bio) MAX_BIO_LENGTH) ERR_INVALID_PARAMS)
    (asserts! (is-valid-optional-url avatar-url) ERR_INVALID_URL)
    
    ;; Create profile
    (map-set user-profiles
      { profile-id: profile-id }
      {
        owner: caller,
        handle: handle,
        bio: bio,
        avatar-url: validated-avatar-url,
        reputation-score: INITIAL_REPUTATION,
        total-tips-received: u0,
        total-tips-sent: u0,
        content-count: u0,
        follower-count: u0,
        following-count: u0,
        created-at: stacks-block-height,
        verified: false
      }
    )
    
    ;; Map handle and principal to profile
    (map-set handle-to-profile handle profile-id)
    (map-set principal-to-profile caller profile-id)
    
    ;; Increment profile counter
    (var-set next-profile-id (+ profile-id u1))
    
    (ok profile-id)
  )
)

;; Update profile information
(define-public (update-profile (bio (string-utf8 256)) (avatar-url (optional (string-ascii 256))))
  (let
    (
      (profile-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
      (profile (unwrap! (map-get? user-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (validated-avatar-url (if (is-valid-optional-url avatar-url) avatar-url none))
    )
    (asserts! (is-eq (get owner profile) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= (len bio) MAX_BIO_LENGTH) ERR_INVALID_PARAMS)
    (asserts! (is-valid-optional-url avatar-url) ERR_INVALID_URL)
    
    (map-set user-profiles
      { profile-id: profile-id }
      (merge profile { bio: bio, avatar-url: validated-avatar-url })
    )
    
    (ok true)
  )
)

;; Follow another user
(define-public (follow-user (target-handle (string-ascii 32)))
  (let
    (
      (follower-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
      (following-id (unwrap! (map-get? handle-to-profile target-handle) ERR_PROFILE_NOT_FOUND))
      (follower-profile (unwrap! (map-get? user-profiles { profile-id: follower-id }) ERR_PROFILE_NOT_FOUND))
      (following-profile (unwrap! (map-get? user-profiles { profile-id: following-id }) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (not (is-eq follower-id following-id)) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? social-connections { follower-id: follower-id, following-id: following-id })) ERR_ALREADY_EXISTS)
    
    ;; Create connection
    (map-set social-connections
      { follower-id: follower-id, following-id: following-id }
      { connected-at: stacks-block-height }
    )
    
    ;; Update follower count
    (map-set user-profiles
      { profile-id: follower-id }
      (merge follower-profile { following-count: (+ (get following-count follower-profile) u1) })
    )
    
    ;; Update following count
    (map-set user-profiles
      { profile-id: following-id }
      (merge following-profile { follower-count: (+ (get follower-count following-profile) u1) })
    )
    
    (ok true)
  )
)

;; PUBLIC FUNCTIONS - CONTENT MANAGEMENT

;; Create content post
(define-public (create-content (content-text (string-utf8 1024)) (content-type (string-ascii 5)) (media-url (optional (string-ascii 256))) (community-id (optional uint)))
  (let
    (
      (content-id (var-get next-content-id))
      (author-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
      (author-profile (unwrap! (map-get? user-profiles { profile-id: author-id }) ERR_PROFILE_NOT_FOUND))
      (validated-media-url (if (is-valid-optional-url media-url) media-url none))
      (validated-community-id (match community-id
        some-id (if (is-some (map-get? communities { community-id: some-id })) community-id none)
        none
      ))
    )
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (<= (len content-text) MAX_CONTENT_LENGTH) ERR_INVALID_PARAMS)
    (asserts! (is-valid-content-type content-type) ERR_INVALID_PARAMS)
    (asserts! (is-valid-optional-url media-url) ERR_INVALID_URL)
    
    ;; Validate community if specified
    (match community-id
      some-community-id (asserts! (is-some (map-get? communities { community-id: some-community-id })) ERR_NOT_FOUND)
      true ;; Return true when no community specified
    )
    
    ;; Create content post
    (map-set content-posts
      { content-id: content-id }
      {
        author-id: author-id,
        content-text: content-text,
        content-type: content-type,
        media-url: validated-media-url,
        tip-count: u0,
        total-tips: u0,
        engagement-score: u0,
        created-at: stacks-block-height,
        community-id: validated-community-id
      }
    )
    
    ;; Update author's content count
    (map-set user-profiles
      { profile-id: author-id }
      (merge author-profile { content-count: (+ (get content-count author-profile) u1) })
    )
    
    ;; Update engagement tracking
    (update-engagement author-id u0 u0 u1)
    
    ;; Increment content counter
    (var-set next-content-id (+ content-id u1))
    
    (ok content-id)
  )
)

;; Tip content with STX
(define-public (tip-content (content-id uint) (amount uint) (message (optional (string-utf8 256))))
  (let
    (
      (content (unwrap! (map-get? content-posts { content-id: content-id }) ERR_CONTENT_NOT_FOUND))
      (tipper-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
      (author-id (get author-id content))
      (author-profile (unwrap! (map-get? user-profiles { profile-id: author-id }) ERR_PROFILE_NOT_FOUND))
      (tipper-profile (unwrap! (map-get? user-profiles { profile-id: tipper-id }) ERR_PROFILE_NOT_FOUND))
      (protocol-fee (calculate-protocol-fee amount))
      (author-amount (- amount protocol-fee))
      (validated-message (if (is-valid-message message) message none))
      (validated-content-id (if (is-some (map-get? content-posts { content-id: content-id })) content-id u0))
    )
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (>= amount MIN_TIP_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tipper-id author-id)) ERR_SELF_TIP)
    (asserts! (> validated-content-id u0) ERR_CONTENT_NOT_FOUND)
    (asserts! (is-none (map-get? content-tips { content-id: validated-content-id, tipper: tx-sender })) ERR_ALREADY_TIPPED)
    (asserts! (is-valid-message message) ERR_INVALID_MESSAGE)
    
    ;; Transfer STX to author
    (try! (stx-transfer? author-amount tx-sender (get owner author-profile)))
    
    ;; Transfer protocol fee
    (try! (stx-transfer? protocol-fee tx-sender (var-get protocol-fee-recipient)))
    
    ;; Record tip
    (map-set content-tips
      { content-id: validated-content-id, tipper: tx-sender }
      {
        amount: amount,
        message: validated-message,
        tipped-at: stacks-block-height
      }
    )
    
    ;; Update content stats
    (map-set content-posts
      { content-id: validated-content-id }
      (merge content 
        { 
          tip-count: (+ (get tip-count content) u1),
          total-tips: (+ (get total-tips content) amount),
          engagement-score: (+ (get engagement-score content) u1)
        }
      )
    )
    
    ;; Update user profiles
    (map-set user-profiles
      { profile-id: author-id }
      (merge author-profile { total-tips-received: (+ (get total-tips-received author-profile) author-amount) })
    )
    
    (map-set user-profiles
      { profile-id: tipper-id }
      (merge tipper-profile { total-tips-sent: (+ (get total-tips-sent tipper-profile) amount) })
    )
    
    ;; Update engagement and reputation
    (update-engagement author-id amount u0 u0)
    (update-engagement tipper-id u0 amount u0)
    (update-reputation author-id (/ amount u1000)) ;; Reputation points based on tips
    
    (ok true)
  )
)

;; PUBLIC FUNCTIONS - COMMUNITY GOVERNANCE

;; Create a new community with social token
(define-public (create-community (name (string-ascii 64)) (description (string-utf8 256)) (token-symbol (string-ascii 8)) (initial-supply uint))
  (let
    (
      (community-id (var-get next-community-id))
      (creator-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (not (var-get protocol-paused)) ERR_UNAUTHORIZED)
    (asserts! (> initial-supply u0) ERR_INVALID_PARAMS)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (asserts! (<= (len name) u64) ERR_INVALID_PARAMS)
    (asserts! (<= (len description) u256) ERR_INVALID_PARAMS)
    (asserts! (> (len token-symbol) u0) ERR_INVALID_PARAMS)
    (asserts! (<= (len token-symbol) u8) ERR_INVALID_PARAMS)
    
    ;; Create community
    (map-set communities
      { community-id: community-id }
      {
        name: name,
        description: description,
        creator-id: creator-id,
        token-symbol: token-symbol,
        total-supply: initial-supply,
        member-count: u1,
        created-at: stacks-block-height,
        governance-threshold: (/ initial-supply u2) ;; 50% threshold
      }
    )
    
    ;; Add creator as first member with all tokens
    (map-set community-members
      { community-id: community-id, member-id: creator-id }
      {
        token-balance: initial-supply,
        joined-at: stacks-block-height,
        is-moderator: true
      }
    )
    
    ;; Increment community counter
    (var-set next-community-id (+ community-id u1))
    
    (ok community-id)
  )
)

;; Join community (requires invitation or open membership)
(define-public (join-community (community-id uint))
  (let
    (
      (member-id (unwrap! (map-get? principal-to-profile tx-sender) ERR_PROFILE_NOT_FOUND))
      (community (unwrap! (map-get? communities { community-id: community-id }) ERR_NOT_FOUND))
      (validated-community-id (if (is-some (map-get? communities { community-id: community-id })) community-id u0))
    )
    (asserts! (> validated-community-id u0) ERR_NOT_FOUND)
    (asserts! (is-none (map-get? community-members { community-id: validated-community-id, member-id: member-id })) ERR_ALREADY_EXISTS)
    
    ;; Add member
    (map-set community-members
      { community-id: validated-community-id, member-id: member-id }
      {
        token-balance: u0,
        joined-at: stacks-block-height,
        is-moderator: false
      }
    )
    
    ;; Update member count
    (map-set communities
      { community-id: validated-community-id }
      (merge community { member-count: (+ (get member-count community) u1) })
    )
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-profile-by-id (profile-id uint))
  (map-get? user-profiles { profile-id: profile-id })
)

(define-read-only (get-profile-by-handle (handle (string-ascii 32)))
  (match (map-get? handle-to-profile handle)
    some-id (map-get? user-profiles { profile-id: some-id })
    none
  )
)

(define-read-only (get-profile-by-principal (user principal))
  (match (map-get? principal-to-profile user)
    some-id (map-get? user-profiles { profile-id: some-id })
    none
  )
)

(define-read-only (get-content (content-id uint))
  (map-get? content-posts { content-id: content-id })
)

(define-read-only (get-tip (content-id uint) (tipper principal))
  (map-get? content-tips { content-id: content-id, tipper: tipper })
)

(define-read-only (is-following (follower-handle (string-ascii 32)) (following-handle (string-ascii 32)))
  (match (map-get? handle-to-profile follower-handle)
    follower-id (match (map-get? handle-to-profile following-handle)
      following-id (is-some (map-get? social-connections { follower-id: follower-id, following-id: following-id }))
      false
    )
    false
  )
)

(define-read-only (get-community (community-id uint))
  (map-get? communities { community-id: community-id })
)

(define-read-only (get-community-member (community-id uint) (member-id uint))
  (map-get? community-members { community-id: community-id, member-id: member-id })
)

(define-read-only (get-user-engagement (profile-id uint) (period uint))
  (map-get? user-engagement { profile-id: profile-id, period: period })
)

(define-read-only (get-protocol-stats)
  {
    total-profiles: (- (var-get next-profile-id) u1),
    total-content: (- (var-get next-content-id) u1),
    total-communities: (- (var-get next-community-id) u1),
    protocol-fee-bps: PROTOCOL_FEE_BPS,
    protocol-paused: (var-get protocol-paused)
  }
)

;; ADMIN FUNCTIONS

(define-public (set-protocol-fee-recipient (new-recipient principal))
  (let ((validated-recipient (if (is-standard new-recipient) new-recipient CONTRACT_OWNER)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set protocol-fee-recipient validated-recipient)
    (ok true)
  )
)

(define-public (pause-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set protocol-paused true)
    (ok true)
  )
)

(define-public (unpause-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set protocol-paused false)
    (ok true)
  )
)

(define-public (verify-profile (profile-id uint))
  (let 
    (
      (profile (unwrap! (map-get? user-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (validated-profile-id (if (is-some (map-get? user-profiles { profile-id: profile-id })) profile-id u0))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> validated-profile-id u0) ERR_PROFILE_NOT_FOUND)
    (map-set user-profiles
      { profile-id: validated-profile-id }
      (merge profile { verified: true })
    )
    (ok true)
  )
)