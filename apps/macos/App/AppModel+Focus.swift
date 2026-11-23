import Foundation

/// Focus sessions from home's Focus card: Nook counts down with you and, when the time is up, celebrates it next to the
/// notch and offers a minute of breathing as the break.
extension AppModel {
    func startFocus(minutes: Int) {
        let timer = FocusTimer.shared
        timer.onFinish = { [weak self] minutes in self?.focusFinished(minutes: minutes) }
        timer.start(minutes: minutes)
        ToastCenter.shared.show(tr("focus.started", minutes), kind: .info)
    }

    private func focusFinished(minutes: Int) {
        let moment = NookMoment(id: "focus-\(UUID().uuidString)", line: tr("focus.done", minutes), mood: .celebrate,
                                action: .breathe, actionTitle: tr("focus.breathe"), seconds: 20)
        if case .moment = viewModel.state {
            viewModel.replaceMoment(moment)
        } else if !viewModel.offerMoment(moment) {
            // You asked for this one: it shows over what is open, as "Breathe with me" does.
            viewModel.show(.moment(moment))
            viewModel.dismissMoment(moment.id, after: moment.seconds)
        }
    }
}
