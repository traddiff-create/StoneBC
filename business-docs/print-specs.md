# StoneBC Business Card — Print Specs

## Dimensions

| | Inches | Pixels @ 300 DPI |
|--|--------|-----------------|
| **Canvas (with bleed)** | 3.75 × 2.25 | 1125 × 675 |
| **Trim (final cut)** | 3.50 × 2.00 | 1050 × 600 |
| **Safe zone (content stays inside)** | 3.25 × 1.75 | 975 × 525 |

Bleed = 0.125" on all sides. Safe zone = 0.125" inside trim on all sides.

## Photoshop Setup

1. File → New → Width: **3.75 in**, Height: **2.25 in**, Resolution: **300 PPI**, Color Mode: **RGB 8-bit**
2. View → Guides → New Guide Layout:
   - Columns: 0, Rows: 0
   - Margin: 0.125 in (bleed), 0.25 in (safe zone)
3. Background color extends to canvas edge (into bleed)
4. All text and logos stay inside safe zone (0.25 in from edge)

## Export Settings

- **Format:** PNG or TIFF (never JPEG for print — compression artifacts on text)
- **Color Mode:** RGB (most digital/online printers accept RGB; ask printer if CMYK required)
- **Bit depth:** 8-bit
- **Resolution:** 300 DPI confirmed at export

If using a professional offset printer (e.g. Moo, Vistaprint Pro, local print shop):
- Convert to **CMYK** before sending: Image → Mode → CMYK Color
- Export as **PDF/X-1a** or **TIFF** at 300 DPI with crop marks

## Brand Colors

| Name | Hex | CMYK (approx) |
|------|-----|---------------|
| Brand Green | `#059669` | C:80 M:0 Y:67 K:0 |
| Brand Blue | `#2563eb` | C:85 M:58 Y:0 K:0 |
| Brand Amber | `#f59e0b` | C:0 M:34 Y:95 K:0 |
| White | `#ffffff` | C:0 M:0 Y:0 K:0 |

## Fonts

- **Headings:** Space Grotesk Bold (700) — download from Google Fonts
- **Body:** Inter Regular/Medium (400/500) — download from Google Fonts

## Card Content

### Front
- Logo: gear icon ⚙ or bike glyph, brandGreen
- Name: "STONE BICYCLE COALITION" — Space Grotesk Bold, brandGreen
- Tagline: "Building Community Through Cycling" — Inter Medium, gray
- Email: info@stonebicyclecoalition.com
- Instagram: @stone_bicycle_coalition
- Address: 315 N 4th St · Rapid City, SD

### Back (existing design)
- Mission statement — Space Grotesk Bold, brandGreen
- QR code → stonebikeco.com
- "stonebikeco.com" wordmark

## Digital Card

URL: `stonebicyclecoalition.com/card`
File: `website/src/card.html`
Includes tap-to-email, tap-to-Instagram, map link, and "Save Contact" (.vcf download).
