# Submission test checklist

## One-time database step

In the Supabase SQL Editor, run `setup_submission_completion.sql` after the existing setup scripts. It adds the database functions used by score saving and draw execution. Do this before testing the website.

## User test

1. Sign up with a fresh user and complete onboarding.
2. Confirm the dashboard shows the selected charity, contribution percentage, plan, and renewal date.
3. Enter five scores on different dates, all between 1 and 45. Confirm newest-first order.
4. Try another score with an existing date. It must fail.
5. Enter a sixth score with a new date. Confirm the oldest score was removed and exactly five remain.
6. Edit one score. Confirm it changes without removing another score.
7. Cancel a subscription, then try to save a score. It must fail.
8. As a winner, upload a JPEG/PNG/WebP scorecard under 5 MB. Confirm it appears in the admin verification queue.

## Admin test

1. Sign in as admin and open Draws.
2. Run a Random simulation. Confirm it does not create a history record.
3. Run an Algorithmic simulation. Confirm it does not create a history record.
4. Publish one simulated draw. Confirm one draw and its entries are created.
5. Try publishing again in the same month. It must fail.
6. Check that 5/4/3-match winners split their tier equally, and an unclaimed 5-match amount becomes the next rollover.
7. In Winners, approve a proof, then mark it paid. Confirm the payment timestamp/status changes.
8. Edit charity content, featured status, and events. Confirm public charity pages update.

## Security and responsive smoke test

1. Open an admin URL while logged out and while logged in as a normal user; both must be denied.
2. Use browser devtools to try a direct score insert/update. It must fail; score writes must use `save_my_score`.
3. Test at mobile width (375 px), tablet width (768 px), and desktop width (1440 px): navigation, signup, dashboard, score form, charities, draw results, and admin tables.
4. Capture screenshots of the working user dashboard, score list, charity selection, admin draw simulation, published draw, and winner approval. Include these with your submission.
