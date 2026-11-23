import Foundation

/// The Tools tab's background parts: the clipboard history and the battery are watched from launch, and a kitchen
/// timer that runs out or a battery that runs low is said next to the notch.
extension AppModel {
    func startTools() {
        ClipboardHistory.shared.start()
        NookTimers.shared.onFinish = { [weak self] timer in
            self?.speakUp(NookMoment(id: "timer-\(timer.id)", line: tr("tools.timer.done", timer.title), mood: .surprised,
                                     seconds: 20), force: true)
        }
        let battery = BatteryWatch.shared
        battery.onAlert = { [weak self] level, full in
            let line = full ? tr("tools.battery.full") : tr("tools.battery.low", level)
            self?.speakUp(NookMoment(id: "battery-\(level)-\(full)", line: line, mood: full ? .done : .worry, seconds: 15),
                          force: !full && level <= 10)
        }
        battery.start()
    }

    /// Shows `moment` next to the notch when Nook may speak; `force` also over what shows (a timer you set, a battery
    /// about to run out).
    private func speakUp(_ moment: NookMoment, force: Bool) {
        if case .moment = viewModel.state {
            viewModel.replaceMoment(moment)
        } else if !viewModel.offerMoment(moment), force {
            viewModel.show(.moment(moment))
            viewModel.dismissMoment(moment.id, after: moment.seconds)
        }
    }
}
