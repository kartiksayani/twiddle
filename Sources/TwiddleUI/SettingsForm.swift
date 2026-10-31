import SwiftUI
import TwiddleCore

public struct SettingsForm: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable private var settings: TwiddleCore.Settings
  private let model: PracticeModel
  private let recorder: HotkeyRecorder
  private let login: LoginSetting

  public init(
    settings: TwiddleCore.Settings, model: PracticeModel, recorder: HotkeyRecorder,
    login: LoginSetting
  ) {
    self.settings = settings
    self.model = model
    self.recorder = recorder
    self.login = login
  }

  private var theme: Theme { Theme(scheme) }
  private var recording: Bool { recorder.state == .recording }
  private var conflict: Bool {
    if case .conflict = recorder.state { return true }
    return false
  }
  private var expanded: Bool { recording || conflict }

  public var body: some View {
    VStack(spacing: 0) {
      Text("Twiddle Settings").fontWeight(.semibold)
        .frame(height: Theme.settingsTitleHeight)
      VStack(spacing: expanded ? Theme.settingsCompactGap : Theme.settingsGroupGap) {
        group {
          row("Summon hotkey") { hotkeyField }
          if expanded {
            Text(message)
              .font(.system(size: Theme.labelSize))
              .foregroundStyle(conflict ? theme.settingsConflict : theme.typed)
              .frame(maxWidth: .infinity, alignment: .trailing)
              .frame(height: Theme.settingsMessageHeight)
              .padding(.horizontal, Theme.settingsRowInset)
          }
          separator
          row("Launch at login", detail: login.error) {
            Toggle(
              "Launch at login",
              isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) })
            )
            .labelsHidden().toggleStyle(SettingsToggleStyle())
          }
        }
        group {
          row("Default mode") {
            segments(
              [.flow, .sprint], labels: ["Flow", "Sprint"], selection: $settings.defaultMode)
          }
          separator
          row("Sprint length") {
            menu("\(model.state.lastSprintLength) seconds") {
              ForEach([15, 30, 60], id: \.self) { length in
                Button("\(length) seconds") { model.setSprintLength(length) }
              }
            }
          }
          separator
          row("Default source") {
            menu(settings.defaultSource.label) {
              ForEach(ContentProvider.Source.defaultSources, id: \.self) { source in
                Button(source.label) { settings.defaultSource = source }
              }
            }
          }
        }
        group {
          row(
            "Mistakes",
            detail: settings.mistakes == .strict
              ? "Strict waits for the right key" : "Forgiving moves on after a mistake",
            height: Theme.settingsDetailHeight
          ) {
            segments(
              [.strict, .forgiving], labels: ["Strict", "Forgiving"], selection: $settings.mistakes)
          }
          separator
          row("Finger hints") {
            Toggle(
              "Finger hints", isOn: Binding(get: { model.hintsOn }, set: { model.setHints($0) })
            ).labelsHidden().toggleStyle(SettingsToggleStyle())
          }
          separator
          row("Theme") {
            segments(
              [.system, .light, .dark], labels: ["System", "Light", "Dark"],
              selection: $settings.theme, horizontalInset: Theme.settingsThemeSegmentInset)
          }
        }
      }
      .padding(.horizontal, Theme.settingsInset)
      .padding(.top, Theme.settingsTop)
      Spacer(minLength: 0)
        .frame(height: expanded ? Theme.settingsCompactBottom : Theme.settingsBottom)
    }
    .font(.system(size: Theme.settingsFont))
    .foregroundStyle(theme.primary)
    .tint(theme.accent)
    .frame(width: Theme.settingsSize.width, height: Theme.settingsSize.height, alignment: .top)
    .ignoresSafeArea()
    .background(theme.settingsBackground)
  }

  private var message: String {
    if conflict { return "Another app is already using \(recorder.label). Try another." }
    return recorder.invalidChord ? "Include ⌘, ⌃ or ⌥." : "esc cancels, ⌫ clears"
  }

  private var hotkeyField: some View {
    HStack(spacing: Theme.labelGap) {
      Button {
        recorder.begin()
      } label: {
        HStack(spacing: Theme.labelGap) {
          Text(recording ? "Type a shortcut" : recorder.label)
            .foregroundStyle(recording ? theme.secondary : theme.primary)
          if recording {
            Rectangle().fill(theme.accent)
              .frame(width: Theme.caretWidth, height: Theme.settingsClearSize)
          }
          Spacer(minLength: 0)
        }
      }
      .buttonStyle(.plain)
      .focusable()
      .onKeyPress(.return) {
        recorder.begin()
        return .handled
      }
      if !expanded, settings.hotkey != nil {
        Button {
          recorder.clear()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: Theme.settingsClearSize)).foregroundStyle(theme.faint)
        }.buttonStyle(.plain).accessibilityLabel("Clear shortcut")
      }
    }
    .font(.system(size: Theme.settingsControlFont, weight: .medium))
    .padding(.horizontal, Theme.settingsControlInset)
    .frame(width: expanded ? Theme.settingsRecordingWidth : Theme.settingsHotkeyWidth)
    .frame(height: expanded ? Theme.settingsRecordingHeight : Theme.settingsControlHeight)
    .background(theme.hair, in: RoundedRectangle(cornerRadius: Theme.settingsControlRadius))
    .overlay {
      RoundedRectangle(cornerRadius: Theme.settingsControlRadius)
        .strokeBorder(
          conflict ? theme.error : recording ? theme.accent : theme.hairStrong,
          lineWidth: Theme.edgeWidth)
    }
    .overlay {
      if recording {
        RoundedRectangle(cornerRadius: Theme.settingsControlRadius)
          .stroke(
            theme.settingsAccent.opacity(Theme.settingsFocusOpacity),
            lineWidth: Theme.settingsFocusWidth)
      }
    }
  }

  private func row<Content: View>(
    _ title: String, detail: String? = nil, height: CGFloat = Theme.settingsRowHeight,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: Theme.labelGap) {
      VStack(alignment: .leading, spacing: Theme.settingsHelpGap) {
        Text(title)
        if let detail {
          Text(detail).font(.system(size: Theme.settingsHelpFont))
            .foregroundStyle(title == "Launch at login" ? theme.error : theme.typed)
            .lineLimit(2).help(detail)
        }
      }
      Spacer(minLength: Theme.labelGap)
      content()
    }
    .padding(.horizontal, Theme.settingsRowInset)
    .frame(height: height)
  }

  private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0, content: content)
      .background(theme.settingsGroup, in: RoundedRectangle(cornerRadius: Theme.settingsRadius))
      .overlay {
        RoundedRectangle(cornerRadius: Theme.settingsRadius)
          .strokeBorder(theme.hair, lineWidth: Theme.edgeWidth)
      }
  }

  private var separator: some View {
    Rectangle().fill(theme.hair).frame(height: Theme.edgeWidth)
      .padding(.horizontal, Theme.settingsRowInset)
  }

  private func segments<Value: Hashable>(
    _ values: [Value], labels: [String], selection: Binding<Value>,
    horizontalInset: CGFloat = Theme.settingsSegmentInsetX
  ) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        Button {
          selection.wrappedValue = value
        } label: {
          Text(labels[index])
            .font(
              .system(
                size: Theme.settingsControlFont,
                weight: selection.wrappedValue == value ? .medium : .regular)
            )
            .foregroundStyle(selection.wrappedValue == value ? theme.primary : theme.secondary)
            .padding(.horizontal, horizontalInset)
            .frame(height: Theme.settingsControlHeight - Theme.settingsSegmentInset * 2)
            .background(
              selection.wrappedValue == value ? theme.settingsSelection : .clear,
              in: RoundedRectangle(
                cornerRadius: Theme.settingsControlRadius - Theme.settingsSegmentInset))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
      }
    }
    .padding(Theme.settingsSegmentInset)
    .background(theme.hair, in: RoundedRectangle(cornerRadius: Theme.settingsControlRadius))
  }

  private func menu<Content: View>(_ label: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    Menu(content: content) {
      HStack(spacing: Theme.settingsMenuGap) {
        Text(label).font(.system(size: Theme.settingsControlFont))
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: Theme.settingsMenuArrowSize)).foregroundStyle(theme.secondary)
      }
      .padding(.horizontal, Theme.settingsControlInset)
    }
    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    .frame(height: Theme.settingsMenuHeight)
    .background(theme.hair, in: RoundedRectangle(cornerRadius: Theme.settingsControlRadius))
  }
}

private struct SettingsToggleStyle: ToggleStyle {
  @Environment(\.colorScheme) private var scheme

  func makeBody(configuration: Configuration) -> some View {
    let theme = Theme(scheme)
    Button {
      configuration.isOn.toggle()
    } label: {
      Capsule().fill(configuration.isOn ? theme.settingsAccent : theme.hairStrong)
        .overlay(alignment: configuration.isOn ? .trailing : .leading) {
          Circle().fill(configuration.isOn ? theme.toggleOnInk : theme.toggleOffInk)
            .frame(width: Theme.settingsToggleKnob, height: Theme.settingsToggleKnob)
            .padding(Theme.settingsSegmentInset)
        }
        .frame(width: Theme.settingsToggleWidth, height: Theme.settingsToggleHeight)
    }
    .buttonStyle(.plain)
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
    }
  }
}
