import Testing
@testable import Spread

@Suite("Overdue Button Configuration Tests")
struct OverdueButtonConfigurationTests {

    /// Setup: no overdue tasks.
    /// Expected: the toolbar button stays hidden.
    @Test("Zero overdue tasks hides the button")
    func zeroOverdueTasksHideTheButton() {
        let config = OverdueButtonConfiguration(overdueCount: 0)

        #expect(config.isVisible == false)
        #expect(config.iconName == "exclamationmark.circle.fill")
        #expect(config.accessibilityLabel == "Overdue tasks")
    }

    /// Setup: one overdue task.
    /// Expected: the button is visible and uses singular accessibility wording.
    @Test("Single overdue task uses singular accessibility text")
    func singleOverdueTaskUsesSingularAccessibilityText() {
        let config = OverdueButtonConfiguration(overdueCount: 1)

        #expect(config.isVisible == true)
        #expect(config.accessibilityLabel == "Overdue tasks, 1 task")
    }

    /// Setup: multiple overdue tasks.
    /// Expected: the button remains visible and includes the count.
    @Test("Multiple overdue tasks include count in accessibility text")
    func multipleOverdueTasksIncludeCountInAccessibilityText() {
        let config = OverdueButtonConfiguration(overdueCount: 4)

        #expect(config.isVisible == true)
        #expect(config.accessibilityLabel == "Overdue tasks, 4 tasks")
    }
}
