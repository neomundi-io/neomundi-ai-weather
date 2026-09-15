# assets/partners/

Drop official partner logo files here. Nothing is committed here by default —
this directory only documents the expected filenames.

## Infomaniak

Expected file: `infomaniak-logo.png`

Referenced by `config/wording.json` → `partners.infomaniak_logo`.

`index.html` checks at runtime whether this file exists (a simple image
load probe — no build step, no hardcoded assumption that it's present).
If it is present, the footer shows:

```
Infrastructure partner
[INFOMANIAK LOGO]
```

If it is absent, nothing is shown — no broken image, no placeholder text
implying a partnership that hasn't been made official.

**Do not** fetch or fabricate this logo from the internet. Only drop the
official asset provided directly by Infomaniak.

The mention must never imply that Infomaniak produces, validates, or
endorses NeoMundi's measurements — it only credits infrastructure.
