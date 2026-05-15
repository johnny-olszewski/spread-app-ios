# Settings

> Source: Documentation/spec.md

### Settings (v1)
- BuJo mode toggle: conventional vs traditional with descriptions. [SPRD-20]
  - Conventional: "Track tasks across spreads with migration history"
  - Traditional: "View tasks on their preferred date only"
- First day of week preference: System Default, Sunday, Monday. [SPRD-49]
  - System Default uses device locale. [SPRD-49]
  - Affects multiday preset calculations. [SPRD-49]
- The previous title-strip display preference is removed. The compact bar shows only the current selection, and the rooted navigator remains the complete browsing surface in both modes. [SPRD-126, SPRD-176, SPRD-177]

### Collections
- Collections are plain text pages (title + content). [SPRD-39]
- Content is plain text with no character limit (unbounded). [SPRD-39]
- Collections live outside spread navigation in a top-level entry point. [SPRD-19, SPRD-40]
- Support create, edit, delete operations. [SPRD-40, SPRD-41]
- Collections list is sorted by modified date, newest first. [SPRD-40]
- Collections sync via Supabase using the same outbox + pull mechanism as other entities. [SPRD-85]
- Collection model fields: id, title, content, createdDate, modifiedDate. [SPRD-39]
- Auto-save on changes (debounced); updates modifiedDate on save. [SPRD-41]

### First Launch and Onboarding
- On first authenticated product launch, a brief onboarding walkthrough is shown (2-3 screens explaining BuJo concepts: spreads, tasks, migration). [SPRD-106]
- Onboarding is shown only once per app install; completion is tracked locally.
- After onboarding dismissal, the user lands on the empty spread view with a clear call-to-action to create their first spread via the "+" button.
- Subsequent authenticated launches skip onboarding and go directly to the spread view.
- Onboarding content (v1):
  - Screen 1: Welcome — brief app description and BuJo philosophy.
  - Screen 2: Spreads — explain year/month/day/multiday pages and how to create them.
  - Screen 3: Tasks and Migration — explain rapid logging, task statuses, and manual migration.
- Onboarding occurs after authentication and does not teach account creation; sign-in remains part of the auth gate flow.
