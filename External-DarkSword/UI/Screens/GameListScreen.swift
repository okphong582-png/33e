//
//  GameListScreen.swift
//  External-DarkSword
//
//  Created by Le Tien Dat on 8/28/26.
//

import Combine
import SwiftUI
import UIKit

struct GameListScreen: View {
    @ObservedObject var manager: DarkSwordManager
    let palette: AppPalette
    let language: AppLanguage
    @State private var isShowingLaunchAlert = false
    @State private var launchAlertMessage = ""
    @State private var diagnosticsCopied = false
    @State private var isWaitingForGameActionResult = false
    @State private var displayedGame: GameTarget = .aov

    private let timer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        let _ = manager.gameStatusVersion

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppStrings.gamesTitle(language))
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(palette.primaryText)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                if manager.isDebug {
                    DebugKernelPanel(
                        manager: manager,
                        palette: palette,
                        language: language
                    )
                    .padding(.horizontal, 22)
                }

                Picker("Game", selection: $displayedGame) {
                    ForEach(GameTarget.allCases) { target in
                        Text(target.name).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(manager.isBusy)
                .padding(.horizontal, 22)

                GameCard(
                    game: manager.gameStatus(for: displayedGame),
                    statusText: displayedGame == manager.selectedGame
                        ? AppStrings.gameCellStatus(manager.aovGameCellStatus, language: language) : nil,
                    isBusy: manager.isBusy && displayedGame == manager.selectedGame,
                    palette: palette
                )
                .padding(.horizontal, 18)

                    Button {
                        isWaitingForGameActionResult = true
                        manager.openGameAndConnect(displayedGame)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showLaunchErrorIfNeeded()
                        }
                    } label: {
                        Label(manager.isBusy ? "Đang khởi động…" : "Start", systemImage: "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(manager.isBusy)
                    .padding(.horizontal, 18)

                if displayedGame == .freeFire {
                    Text("Start mở nút Mizze ở sảnh. Nhấn nút nổi để mở menu.")
                        .font(.footnote)
                        .foregroundColor(palette.secondaryText)
                        .padding(.horizontal, 24)
                    Toggle(AppStrings.text(language, vietnamese: "ESP — khung địch", english: "ESP — enemy boxes"), isOn: $manager.freeFireESPEnabled)
                        .tint(palette.accent)
                        .foregroundColor(palette.primaryText)
                        .padding(.horizontal, 24)
                }

                Button {
                    UIPasteboard.general.string = MizzeStartupReport()
                    diagnosticsCopied = true
                } label: {
                    Label(diagnosticsCopied ? "Đã sao chép nhật ký" : "Sao chép nhật ký khởi tạo", systemImage: "doc.on.doc")
                        .font(.footnote)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        AppStrings.aovStatus(
                            manager.aovStatus,
                            language: language
                        )
                    )
                    .font(
                        .system(.footnote, design: .monospaced).weight(.bold)
                    )
                    .foregroundColor(palette.secondaryText)

                    if !manager.remoteError.isEmpty {
                        Text(manager.remoteError)
                            .font(.footnote)
                            .foregroundColor(.red.opacity(0.92))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, manager.remoteConnected ? 96 : 42)
            }
        }
        .scrollIndicators(.visible)
        .onAppear { displayedGame = manager.selectedGame }
        .alert(
            AppStrings.gameLaunchFailureTitle(language),
            isPresented: $isShowingLaunchAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAlertMessage)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if manager.remoteConnected {
                    Button(action: manager.disconnectRemoteCall) {
                        Label(
                            AppStrings.disconnectAction(language),
                            systemImage: "xmark.circle.fill"
                        )
                        .font(.system(size: 16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(DisconnectButtonStyle(palette: palette))
                    .disabled(manager.isBusy)
                    .padding(.horizontal, 24)
                }

                DeveloperFooter(palette: palette)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(palette.background)
        }
        .onReceive(timer) { _ in
            manager.refreshGameStatuses()
        }
        .onChange(of: manager.remoteError) { _, _ in
            showLaunchErrorIfNeeded()
        }
        .onChange(of: manager.remoteConnected) { _, connected in
            if connected {
                isWaitingForGameActionResult = false
            }
        }
    }

    private func showLaunchErrorIfNeeded() {
        guard isWaitingForGameActionResult else { return }
        guard !manager.remoteError.isEmpty else { return }
        launchAlertMessage = AppStrings.gameLaunchDetails(
            error: manager.remoteError,
            bundleIdentifier: manager.selectedGameBundleIdentifier,
            process: manager.selectedGameProcess,
            status: manager.aovStatus,
            language: language
        )
        isWaitingForGameActionResult = false
        isShowingLaunchAlert = true
    }
}
