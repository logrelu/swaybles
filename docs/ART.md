# Charm art spec

Every Swaybles charm comes from Imagine Art using this template, so all packs look like one set.

## Generation settings
- **Model:** `gpt-image-2.5-flare` · **Background:** `transparent` · **Quality:** `high` · **Aspect:** `1:1` (2048 px)

## Prompt template
Fill in `{SUBJECT}` only. Don't change the rest.

```
A single cute glossy 3D vinyl-toy style charm of {SUBJECT}. A small shiny gold jump ring loop
attached to the top center, as if it hangs from a string. Isolated on a fully transparent
background, no ground shadow, soft studio lighting, playful collectible, high detail, centered
with generous padding around it. No text, no watermark.
```

## Acceptance checks (all must pass, else regenerate once with the same prompt)
| # | Check | How |
|---|---|---|
| 1 | Background is transparent | `npm run charms` warns if any corner is opaque |
| 2 | One object, nothing cut off at the edges | Look at the contact sheet |
| 3 | Gold ring at the top middle | Importer's rope point lands at x 35–65 %, y < 10 %; `npm test` enforces it |
| 4 | Matches the set's style (glossy vinyl, soft light) | Contact sheet next to an existing pack |
| 5 | Reads clearly at 150 px tall | Contact sheet at app size |
| 6 | No brand characters, memes or real people | Human review |

## Functional charms (timer, quotes, banners, tags)
Some charms carry information. **Never put text or numbers in the generated image**: AI text is
unreliable, and every new quote would cost a new image. Instead, generate a **blank surface** and let
the app draw on it.

- Add to `{SUBJECT}`: "holding a completely blank <surface>, the <surface> is plain and empty with
  no text, no letters, no numbers, no symbols".
- After import, record where the blank surface sits in `tools/packs.json` as
  `"label": { "x": 0.2, "y": 0.55, "w": 0.6, "h": 0.25, "shape": "rect" | "circle" }`
  (fractions of the charm image).
- Extra acceptance check: **7. The surface is truly blank and big enough** (≥ 30% of the charm's
  width) to fit 2 short lines of text at app size.

Reactions (cheer, doze, wiggle) are made with physics and app-drawn effects, not extra pose images.

## Files
- Original: `art/raw/<pack>/<id>.png` (2048 px, as downloaded)
- App copy: `src/charms/<pack>/<id>.png` (made by `npm run charms`, max 600 px)
