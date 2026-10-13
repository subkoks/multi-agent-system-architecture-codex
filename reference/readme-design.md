# BLACK.TERMINAL README design

The project family uses the orange identity established by [the GitHub profile](https://github.com/subkoks): a quiet dark canvas, simple typography, fine separators, and deliberate orange accents. The layout takes inspiration from [Factory](https://factory.com/product/cli); the artwork and wording are original.

## Palette and typography

| Token | Value | Use |
| :--- | :--- | :--- |
| Accent | `#FF7F0E` | Marks, routing lines, small labels on dark artwork |
| Canvas | `#111110` | Self-contained banner and diagram backgrounds |
| Surface | `#1B1A18` | Diagram nodes |
| Primary ink | `#F3F0EB` | Artwork titles |
| Secondary ink | `#B5B0A8` | Artwork captions |
| Rule | `#393632` | Decorative separators |

Use system sans-serif for artwork titles and `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace` for small labels. Body text, headings, links, and code retain GitHub's native typography and theme. No font downloads are needed. Orange text belongs on the dark canvas; on a light page it is a decorative mark, not the sole carrier of information.

## Composition

1. A compact project-specific banner: BLACK.TERMINAL identity, project name, category, and a short factual descriptor.
2. A plain-text purpose statement and a short navigation row.
3. The fastest useful starting point: installation, a usage example, or a download with its release caveats.
4. One useful visual: an architecture diagram for agent tools, real application screenshots for native apps, or a concise project map for research.
5. Native Markdown sections for configuration, verification, documentation, and license.

Use a single main heading, sentence-case section headings, left alignment, and short paragraphs. Keep only useful badges. Preserve meaningful heading anchors when refreshing existing READMEs. Put long directory trees and historical details in disclosure sections; keep security and release caveats visible.

## Artwork contract

- Commit static SVG files under `assets/readme/`, referenced with relative paths. Each repository owns its artwork; reading it does not depend on a shared asset service.
- Use a compact desktop banner and a separately composed mobile banner selected with `<picture>` at 600px. Do the same for diagrams that become illegible when reduced.
- Include a descriptive SVG title and meaningful image alt text. Keep essential instructions and commands in Markdown, so they remain usable without images.
- Use a self-contained dark canvas in both GitHub themes. Verify contrast within the artwork and surrounding page readability in both themes.
- SVGs contain no scripts, external resources, embedded HTML, or animation. Use real system-font text, not outlined paragraphs.
- Adapt the visual to the project. Preserve existing app screenshots and current release status. The four-endpoint motif in this repository represents agent coordination; other projects should use their own subject.

GitHub sanitizes HTML and removes inline styles. It supports themed/responsive images through `<picture>`, but ordinary README text cannot be given arbitrary CSS or custom fonts. See [the rendering pipeline](https://github.com/github/markup) and [GitHub's image guidance](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github).

## Acceptance and rollout

Check 360px, 768px, and 1280px layouts in light and dark themes; ensure titles and diagram labels fit. Check image availability, alt text, section navigation, relative links, and preserved command blocks. Use the repository's existing documentation checks, then review the diff before publishing.

Roll out one repository at a time, using isolated checkouts when local work is dirty. Begin with this architecture repository, then native apps, security/tools, and strategy/implementation repositories. The profile and about-me pages already establish the identity and need only consistency review. Preserve the profile's activity branch and graph pipeline.

Rollback is a normal revert of the documentation commit. No runtime configuration, installation, or application behavior is part of the visual change.
