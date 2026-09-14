# Maximizing Collaboration Efficiency

## When to use /collab vs working solo

Don't use `/collab` for everything. It adds 15-60 seconds per Codex call and consumes context window space. Use it when the value justifies the cost.

### High-value collab tasks

| Scenario | Mode | Why collab helps |
|----------|------|-----------------|
| Architecture decision with real trade-offs | Think | Two models surface different concerns |
| Building an isolated module with clear interfaces | Build | Codex implements while you stay productive |
| Bug that resisted your first debugging attempt | Debug | Independent hypotheses prevent confirmation bias |
| Pre-commit review after a long coding session | Review | Fresh model catches normalized mistakes |
| Evaluating two competing technical approaches | Think | Adversarial debate produces stronger analysis |

### Low-value collab tasks (just use Claude directly)

- Simple questions you already know the answer to
- Quick edits to a single file
- Tasks requiring deep context about your specific codebase
- Anything where you need back-and-forth conversation to clarify requirements

## Writing effective task descriptions

The quality of the collaboration depends heavily on how you describe the task.

### Think mode

**Bad:** `/collab Should we refactor the database?`
— Too vague. Claude can't form a meaningful position, Codex can't challenge it.

**Good:** `/collab Should we migrate from raw SQL queries to an ORM (Drizzle) for our PostgreSQL database? We have 47 queries across 12 files. Consider migration effort, type safety, and query performance.`
— Specific enough for both models to reason about concretely.

### Build mode

**Bad:** `/collab Build the user profile feature`
— No boundaries. Codex will make assumptions about everything.

**Good:** `/collab Build a UserProfileCard component at src/components/user-profile-card.tsx that accepts {name: string, email: string, avatarUrl?: string} props. Use Tailwind for styling. Include a test file.`
— Clear interfaces, clear constraints, clear deliverables.

### Debug mode

**Bad:** `/collab Something is broken`
— Useless. Neither model can help without symptoms.

**Good:** `/collab The POST /api/users endpoint returns 500 when the email contains a + character. Error: "invalid input syntax for type uuid". Relevant files: src/app/api/users/route.ts, src/lib/db/users.ts`
— Specific symptoms, specific error, specific files.

## Chaining collaboration patterns

For complex features, chain think → build:

```
# Step 1: Debate the approach
/collab What's the best way to implement rate limiting for our API? 
Consider token bucket vs sliding window vs fixed window. 
We use Next.js API routes with Vercel serverless.

# Step 2: Build the agreed-upon approach
/collab Build the sliding window rate limiter we discussed. 
Create src/lib/rate-limiter.ts with the middleware function 
and src/lib/__tests__/rate-limiter.test.ts with tests.
```

## Context window management

Each Codex call adds its response to Claude's context. In a long session with many collab rounds, this adds up.

**Signs context is getting tight:**
- Claude's responses become less detailed
- Claude starts forgetting earlier parts of the conversation
- Build specs become less specific

**What to do:**
- Start a new Claude Code session for fresh context
- Ask Claude to compact before the next collab round
- Break remaining work into smaller tasks

## Adapting for your tech stack

The slash commands reference TypeScript/Next.js conventions. Edit `.claude/commands/collab.md` to match your project:

1. Replace `npm test` with your test command
2. Replace framework references (shadcn/ui, Tailwind) with yours
3. Update the "Project conventions" line in the critical rules section
4. Add your project's file organization patterns

## Adapting the Codex model

Edit `.claude/bin/codex-bridge.sh` to change the model:

```bash
# Default (recommended for most tasks)
-m gpt-5.4

# Faster, cheaper for simple tasks
-m gpt-5.4-mini

# Maximum reasoning power
-m o3
```
