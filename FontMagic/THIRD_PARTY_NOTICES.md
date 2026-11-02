# Third-party font notice

FontMagic contains 120 `.ttf`/`.otf` files in its built-in font categories.
Those font files are third-party works and are not covered by FontMagic's code
notice.

The current source archive does not contain reliable per-font source, author,
or license records. Some files contain embedded copyright or use statements,
but those statements do not establish that this package may redistribute the
files. In particular, the embedded metadata inspected during release auditing
includes these restrictions:

- `Popular/Expressway.ttf` and `Easy-to-Read/Takeaway.ttf` contain statements
  forbidding redistribution without permission.
- `Popular/CalibriBold.ttf` limits use to the EULA of the product that supplied
  the font, while `Easy-to-Read/SF-Pro.ttf` contains Apple product/platform and
  embedding restrictions.
- `Popular/914Solid.ttf`, `Fun/Acadian.ttf`, `Fun/Deltarune.ttf`,
  `Fun/Ruritania.ttf`, `Fun/The Centurion .ttf`, `Fun/WaltographUI.ttf`,
  `Future/digital-7.ttf`, `Random/Midorima.ttf`, `Random/WhoAsksSatan.ttf`, and
  `Random/edgyh.ttf` contain personal-use, demo, or non-commercial terms.

A filename, font family name, or local copy of a font is not evidence of
redistribution permission. This notice records the known risk; it does not
override or grant rights under any font license.

Before publishing or redistributing a package that contains these fonts, the
distributor should establish and record the license/provenance of every bundled
font, remove any file whose redistribution rights cannot be verified, and add
the notices required by each verified license. `Core/Fonts.lua` is the
authoritative inventory of bundled font paths.

Users may instead install fonts they are entitled to use through the optional
`FontMagicCustomFonts` companion. FontMagic does not grant rights to those user
supplied files.
