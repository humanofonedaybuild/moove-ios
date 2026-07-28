import SwiftUI
import MooveKit

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: MooveSpacing.sm) {
            ForEach(AlarmConfig.weekdayOrder, id: \.self) { day in
                DayChip(
                    label: shortLabel(for: day),
                    isSelected: selection.contains(day)
                ) {
                    if selection.contains(day) {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                }
            }
        }
    }

    private func shortLabel(for day: Int) -> String {
        switch day {
        case 1: return "M"
        case 2: return "T"
        case 3: return "W"
        case 4: return "T"
        case 5: return "F"
        case 6: return "S"
        case 7: return "S"
        default: return ""
        }
    }
}
