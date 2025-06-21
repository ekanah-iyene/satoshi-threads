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

;; Protocol configuration
(define-constant PROTOCOL_FEE_BPS u250) ;; 2.5% protocol fee
(define-constant MIN_TIP_AMOUNT u1000) ;; Minimum tip in microSTX
(define-constant MAX_HANDLE_LENGTH u32)
(define-constant MAX_BIO_LENGTH u256)
(define-constant MAX_CONTENT_LENGTH u1024)
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
    content-type: (string-ascii 16), ;; "text", "image", "video", etc.
    media-url: (optional (string-ascii 256)),
    tip-count: uint,
    total-tips: uint,
    engagement-score: uint,
    created-at: uint,
    community-id: (optional uint)
  }
)