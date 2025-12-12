TALOWA APP – COMPLETE SYSTEM ANALYSIS REQUEST

You are acting as a Top 1% senior Flutter + Firebase architect.
Your task is to fully understand my TALOWA app before writing or changing any code.

📌 Step 1: Full Codebase Scan (MANDATORY)

Scan every file in the project, including but not limited to:

/lib/**

/web/**

/functions/** (if present)

pubspec.yaml

Firebase config files

Firestore rules

Storage rules

Indexes

Environment / build configs

Do not assume anything.
Do not generate new code yet.

📌 Step 2: Produce a Complete App Architecture Map

Explain clearly:

App navigation flow (auth → home → tabs → features)

State management approach (provider, riverpod, bloc, setState, mixed?)

Firebase services used (Auth, Firestore, Storage, Functions, Messaging)

Platform targets (Android, Web, iOS)

Where critical logic lives (services, screens, widgets)

📌 Step 3: Authentication & Security Flow (DETAILED)

Explain exactly:

How users register

How OTP + PIN works

How sessions are restored

Where auth breaks or duplicates occur

Firestore & Storage permission logic

Any security risks or inconsistencies

📌 Step 4: Feed System Analysis (CRITICAL)

Explain in detail:

How posts are created (or not)

Where image/video/text upload should happen

Which Firebase collections are used

Why feed tab shows white screen

Why images don’t appear but videos might

Model mismatches or placeholder logic

Missing services or broken integrations

📌 Step 5: Performance & Scalability Review

Analyze:

Firestore read/write patterns

Infinite listeners / snapshot misuse

Referral chain scalability issues

Why app hangs or keeps loading

Network tab delays (5–10 minutes)

Storage & CORS impact

Web-specific performance blockers

📌 Step 6: Data Consistency & Duplication Check

Identify:

Duplicate referral codes

Duplicate user records

Conflicting collections (users vs user_registry)

Inconsistent field names

Broken indexes

📌 Step 7: Produce OUTPUT IN MARKDOWN ONLY

Your response must include:

CURRENT_STATE_SUMMARY.md

CRITICAL_BROKEN_AREAS.md

WHAT_IS_MISSING.md

WHY_FEATURES_ARE_NOT_WORKING.md

SAFE_REBUILD_STRATEGY.md

Do not implement fixes yet.
Do not refactor code yet.
Only analyze and explain.

⚠️ STRICT RULES

No simulated implementations

No TODO placeholders

No partial answers

No skipping files

No assumptions

No rebuilding until analysis is complete