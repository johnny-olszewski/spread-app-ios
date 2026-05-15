# Accessibility

> Source: Documentation/spec.md

### Accessibility (v1)
- **VoiceOver**: All interactive elements (buttons, list rows, toggles, pickers) must have descriptive accessibility labels. Entry rows announce entry type, title, and status (e.g., "Task, Buy groceries, open"). [SPRD-TBD]
- **Dynamic Type**: Body text and entry list content support Dynamic Type at standard text sizes. Accessibility text sizes (xxxLarge and above) are not required for v1.
- **Color contrast**: All text and interactive elements meet minimum contrast ratios against their backgrounds (4.5:1 for normal text, 3:1 for large text).
- **Reduce Motion**: Not required for v1. Revisit post-v1 if animations are added.
- **Switch Control**: Not explicitly targeted for v1; standard SwiftUI controls provide baseline support.
