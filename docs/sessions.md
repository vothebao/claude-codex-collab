# Example Collaboration Sessions

## Example 1: Think mode — Architecture debate

**Prompt:**
```
/collab Should we use event-driven architecture or cron-based scheduling for background jobs?
```

**What happens:**

1. Claude reads your codebase, identifies the current job scheduling approach
2. Claude forms its position (e.g., "event-driven is better because...")
3. Claude calls Codex:
   ```bash
   .claude/bin/codex-bridge.sh think "We're deciding between event-driven (Inngest/BullMQ) 
   vs cron-based scheduling for background jobs in a Next.js/Supabase app. 
   My position: event-driven is superior because of retry semantics and fan-out patterns. 
   Challenge my assumptions. Where am I wrong?"
   ```
4. Codex responds with counter-arguments (e.g., "cron is simpler for periodic tasks, event-driven adds operational complexity...")
5. Claude synthesizes: "We agree on X, diverge on Y, my recommendation is Z"

**Time:** ~45 seconds total

---

## Example 2: Build mode — Delegated implementation

**Prompt:**
```
/collab Build a rate limiter middleware for our API routes. Sliding window algorithm, 
100 requests per minute per IP. Include tests.
```

**What happens:**

1. Claude analyzes the codebase, writes a spec to `.collab/specs/rate-limiter.md`:
   ```markdown
   # Rate Limiter Middleware
   
   ## Objective
   Sliding window rate limiter for Next.js API routes.
   
   ## Files to create
   - src/lib/middleware/rate-limiter.ts
   - src/lib/middleware/__tests__/rate-limiter.test.ts
   
   ## Files DO NOT touch
   - src/app/api/** (integration comes later)
   - src/lib/db/** (no database changes)
   
   ## Interfaces
   export function rateLimiter(options: { windowMs: number; maxRequests: number }): 
     (req: NextRequest) => Promise<NextResponse | null>
   
   ## Constraints
   - Use Map for in-memory storage (no Redis for now)
   - TypeScript strict mode
   - Named exports only
   
   ## Verification
   npm test must pass
   ```

2. Claude launches Codex in background:
   ```bash
   .claude/bin/codex-bridge.sh build "Implement this spec exactly." .collab/specs/rate-limiter.md > .collab/codex-output.txt 2>&1 &
   ```

3. Claude tells you: "Codex is building. I'll check in 90 seconds. You can keep chatting."

4. You ask Claude about something else while waiting.

5. Claude checks: "Done. Reviewing..." → runs `git diff`, runs `npm test`, confirms 8/8 tests pass.

6. Claude reports: "Built and verified. Two files, 8 tests passing, clean implementation."

**Time:** ~2 minutes (but you were productive the whole time)

---

## Example 3: Debug mode — Competing hypotheses

**Prompt:**
```
/collab Users report 500 errors on POST /api/users when email contains a + character. 
Error: "invalid input syntax for type uuid"
```

**What happens:**

1. Claude reads the error, examines relevant files, forms Hypothesis A:
   "The + character is being URL-decoded and corrupting the UUID parsing in the lookup query"

2. Claude asks Codex independently (without sharing its hypothesis):
   ```bash
   .claude/bin/codex-bridge.sh think "Bug: POST /api/users returns 500 when email has + character. 
   Error: 'invalid input syntax for type uuid'. 
   Files: src/app/api/users/route.ts, src/lib/db/users.ts. 
   Form your own hypothesis about the root cause. Reason from the evidence."
   ```

3. Codex forms Hypothesis B:
   "The email is being used as a lookup key where a UUID is expected — the route handler is passing the email to a function that expects a user ID"

4. Claude compares: hypotheses diverge. Designs a test to discriminate:
   "If A is right, valid emails without + should work. If B is right, ALL emails should fail on this code path."

5. Claude runs the test, B is confirmed, fixes the parameter mismatch.

**Time:** ~60 seconds

---

## Example 4: Quick review

**Prompt:**
```
/collab-review
```

**What happens:**

1. Claude runs `git diff`, sees 3 files changed
2. Claude summarizes the changes, calls Codex:
   ```bash
   .claude/bin/codex-bridge.sh think "Review these changes in a TypeScript/Next.js project. 
   Focus on bugs, edge cases, type safety. Be concise.
   Files: src/lib/auth.ts, src/app/api/login/route.ts, src/middleware.ts
   Summary: Added JWT refresh token rotation with 7-day expiry."
   ```
3. Codex flags two concerns
4. Claude agrees with one, disagrees with the other, presents both with reasoning

**Time:** ~20 seconds
