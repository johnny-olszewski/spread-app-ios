#if DEBUG
import Foundation
import Testing
@testable import Spread

/// Tests for DebugAppearanceSettings functionality.
///
/// Validates that appearance overrides work correctly and that
/// reset restores spec defaults. The `#if DEBUG` guard on
/// `DebugAppearanceSettings` ensures these controls are excluded
/// from Release builds.
@Suite("DebugAppearanceSettings Tests")
@MainActor
struct DebugAppearanceSettingsTests {

    // MARK: - Helpers

    /// Creates a fresh settings instance and resets to defaults before each test.
    private func makeSettings() -> DebugAppearanceSettings {
        let settings = DebugAppearanceSettings.shared
        settings.resetToDefaults()
        return settings
    }

    // MARK: - Default Values

    /// Condition: Settings are at defaults.
    /// Expected: All values match spec defaults.
    @Test("Default values match spec")
    func testDefaultValues() {
        let settings = makeSettings()

        #expect(settings.paperTone == .warmOffWhite)
        #expect(settings.isDotGridVisible == true)
        #expect(settings.dotSize == 1.5)
        #expect(settings.dotSpacing == 20)
        #expect(settings.dotOpacity == 0.22)
        #expect(settings.headingFont == .avenirNext)
        #expect(settings.accentColor == .mutedBlue)
    }

    // MARK: - Paper Tone

    /// Condition: Change paper tone to clean white.
    /// Expected: Paper tone is updated.
    @Test("Changing paper tone persists")
    func testChangingPaperTone() {
        let settings = makeSettings()

        settings.paperTone = .cleanWhite

        #expect(settings.paperTone == .cleanWhite)
    }

    /// Condition: Change paper tone to cool gray.
    /// Expected: Paper tone is updated.
    @Test("Cool gray paper tone preset works")
    func testCoolGrayPreset() {
        let settings = makeSettings()

        settings.paperTone = .coolGray

        #expect(settings.paperTone == .coolGray)
    }

    // MARK: - Dot Grid

    /// Condition: Toggle dot grid off.
    /// Expected: Dot grid is hidden.
    @Test("Toggling dot grid visibility")
    func testTogglingDotGridVisibility() {
        let settings = makeSettings()

        settings.isDotGridVisible = false

        #expect(settings.isDotGridVisible == false)
    }

    /// Condition: Change dot size.
    /// Expected: Dot size is updated.
    @Test("Changing dot size persists")
    func testChangingDotSize() {
        let settings = makeSettings()

        settings.dotSize = 3.0

        #expect(settings.dotSize == 3.0)
    }

    /// Condition: Change dot spacing.
    /// Expected: Dot spacing is updated.
    @Test("Changing dot spacing persists")
    func testChangingDotSpacing() {
        let settings = makeSettings()

        settings.dotSpacing = 30

        #expect(settings.dotSpacing == 30)
    }

    /// Condition: Change dot opacity.
    /// Expected: Dot opacity is updated.
    @Test("Changing dot opacity persists")
    func testChangingDotOpacity() {
        let settings = makeSettings()

        settings.dotOpacity = 0.4

        #expect(settings.dotOpacity == 0.4)
    }

    // MARK: - Typography

    /// Condition: Change heading font to system.
    /// Expected: Heading font is updated.
    @Test("Changing heading font persists")
    func testChangingHeadingFont() {
        let settings = makeSettings()

        settings.headingFont = .system

        #expect(settings.headingFont == .system)
    }

    // MARK: - Accent Color

    /// Condition: Change accent color to teal.
    /// Expected: Accent color is updated.
    @Test("Changing accent color persists")
    func testChangingAccentColor() {
        let settings = makeSettings()

        settings.accentColor = .teal

        #expect(settings.accentColor == .teal)
    }

    // MARK: - Dot Grid Configuration

    /// Condition: Dot grid visible with custom settings.
    /// Expected: Dot grid configuration reflects overrides.
    @Test("Dot grid configuration reflects overrides")
    func testDotGridConfigurationReflectsOverrides() {
        let settings = makeSettings()
        settings.dotSize = 2.5
        settings.dotSpacing = 25

        let config = settings.dotGridConfiguration

        #expect(config.dotSize == 2.5)
        #expect(config.dotSpacing == 25)
    }

    // MARK: - Reset

    /// Condition: Multiple settings changed, then reset.
    /// Expected: All values return to spec defaults.
    @Test("Reset restores all defaults")
    func testResetRestoresAllDefaults() {
        let settings = makeSettings()

        // Change everything
        settings.paperTone = .coolGray
        settings.isDotGridVisible = false
        settings.dotSize = 4.0
        settings.dotSpacing = 8
        settings.dotOpacity = 0.5
        settings.headingFont = .georgia
        settings.accentColor = .indigo

        // Reset
        settings.resetToDefaults()

        // Verify all defaults restored
        #expect(settings.paperTone == .warmOffWhite)
        #expect(settings.isDotGridVisible == true)
        #expect(settings.dotSize == 1.5)
        #expect(settings.dotSpacing == 20)
        #expect(settings.dotOpacity == 0.22)
        #expect(settings.headingFont == .avenirNext)
        #expect(settings.accentColor == .mutedBlue)
    }

    // MARK: - Preset Coverage

    /// Condition: All paper tone presets have distinct display names.
    /// Expected: Each preset has a unique display name.
    @Test("All paper tone presets have unique display names")
    func testPaperTonePresetsHaveUniqueNames() {
        let names = DebugAppearanceSettings.PaperTonePreset.allCases.map(\.displayName)
        let uniqueNames = Set(names)
        #expect(uniqueNames.count == names.count)
    }

    /// Condition: All accent color presets have distinct display names.
    /// Expected: Each preset has a unique display name.
    @Test("All accent color presets have unique display names")
    func testAccentColorPresetsHaveUniqueNames() {
        let names = DebugAppearanceSettings.AccentColorPreset.allCases.map(\.displayName)
        let uniqueNames = Set(names)
        #expect(uniqueNames.count == names.count)
    }

    /// Condition: All heading font presets have distinct display names.
    /// Expected: Each preset has a unique display name.
    @Test("All heading font presets have unique display names")
    func testHeadingFontPresetsHaveUniqueNames() {
        let names = DebugAppearanceSettings.HeadingFont.allCases.map(\.displayName)
        let uniqueNames = Set(names)
        #expect(uniqueNames.count == names.count)
    }
}
#endif
