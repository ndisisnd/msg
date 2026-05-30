---
name: UX Laws
description: Gestalt, Fitts's Law, Hick's Law, and Nielsen's 10 heuristics; indexed for lazy loading, with detail per law
type: reference
---

# UX laws

Load the index always. Load a law's detail block only when that law is selected in the interview. Name the applied law on every layout decision.

## Index

| Law | One line |
|-----|----------|
| Fitts's Law | Time to hit a target grows with distance and shrinks with target size. |
| Hick's Law | Decision time grows with the number and complexity of choices. |
| Gestalt: Proximity | Elements placed close together are read as one group. |
| Gestalt: Similarity | Elements that share form are read as related. |
| Gestalt: Common region | A shared boundary (card, panel) groups its contents. |
| Progressive disclosure | Show only what is needed now; defer the rest to later steps. |
| Nielsen 1: Visibility of system status | Keep the user informed with timely feedback. |
| Nielsen 2: Match system and real world | Use the user's language and familiar conventions. |
| Nielsen 3: User control and freedom | Provide undo, redo, and clear exits. |
| Nielsen 4: Consistency and standards | Same word and action means the same thing everywhere. |
| Nielsen 5: Error prevention | Stop errors before they happen; confirm destructive actions. |
| Nielsen 6: Recognition over recall | Show options; do not force the user to remember them. |
| Nielsen 7: Flexibility and efficiency | Offer accelerators for expert users. |
| Nielsen 8: Aesthetic and minimalist design | Remove content that competes with the essential. |
| Nielsen 9: Help users with errors | State the problem in plain language; suggest a fix. |
| Nielsen 10: Help and documentation | Provide searchable, task-focused help when needed. |

## Fitts's Law

- Make primary targets large and place them where the thumb or cursor already rests.
- Minimum tap target: 44×44pt (iOS) / 48×48dp (Android). Never smaller for a primary action.
- Edges and corners are infinitely deep targets — anchor key actions to screen edges.
- **Applied**: A bottom-anchored 48px "Continue" button on a mobile onboarding screen — large, thumb-reachable, edge-anchored.

## Hick's Law

- Reduce the number of choices on a single screen to speed decisions.
- Group and stage choices; use progressive disclosure for long option sets.
- Highlight one recommended default to collapse the decision to a yes/no.
- **Applied**: A goal-selection screen shows 4 goals, not 12 — one tap, one decision per scroll.

## Gestalt principles

- **Proximity**: Tighten spacing inside a group; widen spacing between groups. Spacing is the grouping signal.
- **Similarity**: Give related controls the same shape, size, and color role.
- **Common region**: Wrap a related set in a card or panel to bind it without extra labels.
- **Applied**: A settings list groups "Account" rows in one card and "Notifications" rows in another — proximity plus common region, no section headers needed.

## Progressive disclosure

- Show the minimum needed to act now; reveal advanced or secondary options on demand.
- Stage multi-input flows into one decision per step.
- Use accordions, "more options", and step wizards to defer complexity.
- **Applied**: A wearable-connect screen asks only to connect one device first; sync settings appear after a device is linked.

## Nielsen's 10 heuristics

- **Visibility of system status**: Show a progress bar during sync; confirm save with inline feedback.
- **Match the real world**: Label a step "Connect your watch", not "Initialize BLE handshake".
- **User control and freedom**: Put a back arrow and a skip link on every onboarding step.
- **Consistency and standards**: One primary button style across all screens.
- **Error prevention**: Disable "Continue" until a required goal is selected.
- **Recognition over recall**: Pre-fill known data; show device names, not IDs.
- **Flexibility and efficiency**: Offer "Skip for now" for power users who configure later.
- **Aesthetic and minimalist design**: One headline, one sub-line, one action per onboarding screen.
- **Help users recognize and recover from errors**: "Watch not found — make sure Bluetooth is on" with a retry button.
- **Help and documentation**: Link a short "How syncing works" beside the connect action.
- **Applied**: An onboarding step pairs a progress indicator (status), a plain-language title (real world), and a disabled-until-valid CTA (error prevention) on one screen.
