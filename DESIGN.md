# DESIGN.md - Celenganku Pintar

Direction, Identity, and Anti-Slop Visual Language for the Celengan Pintar Mobile Application.

---

## 1. Design Read & Dials

> **Design Read**: Mobile IoT companion application for parents and children tracking physical piggy-bank coin deposits, crafted in a warm, tactile, authentic modern editorial aesthetic.
> **Dials**: **ENERGY 2 / RHYTHM 2 / MOTION 2**

- **ENERGY 2 (Balanced)**: Warm and human, avoiding cold corporate SaaS defaults and avoiding childish cartoon clutter.
- **RHYTHM 2 (Structured with Visual Variety)**: Varied section compositions that reflect physical savings (coin vault hero, milestone journey, ledger feed).
- **MOTION 2 (Meaningful Feedback)**: Smooth counter increment, tactile haptics, and a lively celebratory deposit notification banner when coins are inserted.

---

## 2. Core Personality & Anti-Slop Tenets

1. **No AI Tropes**:
   - No generic purple-blue gradients or full-page glowing meshes.
   - No meaningless badges ("AI-powered", "Smart Savings 300%").
   - No em dashes (`—`) in copy.
   - No floating uniform cards with gigantic blurred shadows.
   - No fake statistics or phantom testimonials.
2. **Tactile Craft**:
   - Real currency formatting (Rupiah `Rp 15.000` with clean Indonesian locale).
   - Real-world piggy bank metaphor: coin slot awareness, milestone badges, tactile coin feedback.
   - High accessibility: WCAG AA contrast on all text, generous touch targets (minimum 48px).
3. **Parent & Child Empathy**:
   - Encouraging, transparent, and joyful.
   - Immediate feedback when a coin drops physically into the ESP32 bank.

---

## 3. Color Palette & Typography

### Palette (Strict 3 Colors + 1 Deliberate Accent)

- **Primary / Heritage Forest**: `#064E3B` (Deep Emerald Green, representing growth, stability, and savings).
- **Secondary / Mint Slate**: `#0D9488` (Teal-green for interactive elements and active progress).
- **Canvas / Warm Paper**: `#F8FAFC` (Clean slate-chalk background) and `#FFFFFF` (Card surfaces).
- **Deliberate Accent / Golden Coin**: `#D97706` / `#F59E0B` (Warm brass coin accent, used strictly for deposit moments and goal stars).

### Typography

- **Headings & Numbers**: *Plus Jakarta Sans* or *Outfit* with bold, geometric numbers for clear legibility from afar.
- **Body & Labels**: Clean, human proportions with natural spacing (no excessive tracking).

---

## 4. Notification & Realtime Feedback System

When a child drops a coin into the physical piggy bank (ESP32):

1. **Realtime Detection**: The Firebase stream catches the change immediately (< 1s).
2. **Tactile In-App Toast / Banner**: A prominent, lively banner slides down from top:
   - Header: *"Koin Baru Masuk! 🎉"*
   - Amount: *"+Rp 1.000"* with warm coin glyph.
   - Context: *"Tabungan Azka bertambah!"*
3. **Sound / Haptic Emulation**: Trigger device haptic vibration (`HapticFeedback.mediumImpact()`).
4. **Hero Balance Roll**: The main balance animates with an ease-out rolling counter.
5. **Goal Alert**: If the target is met, an in-app celebratory banner unlocks with achievement confetti.
