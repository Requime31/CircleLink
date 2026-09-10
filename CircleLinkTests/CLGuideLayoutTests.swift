import Combine
import SwiftUI
import UIKit
import XCTest
@testable import CircleLink

/// Hosting tests exercise actual SwiftUI measurement, which the pure placement tests cannot cover.
@MainActor
final class CLGuideLayoutTests: XCTestCase {
    func testNarrowCardMeasuresContentInsteadOfPositionedContainer() async {
        await verifyLayout(size: CGSize(width: 320, height: 568), dynamicType: .large)
    }

    func testLandscapeAccessibilityContentUsesScrollablePanel() async {
        await verifyLayout(size: CGSize(width: 568, height: 320), dynamicType: .accessibility5)
    }

    func testHostWaitsForReadyContentAndSwitchesNavigationDestinations() async {
        let defaults = UserDefaults(suiteName: "GuideHost.\(UUID().uuidString)")!
        let manager = ContextualGuideManager(repository: MockUserRepository(), defaults: defaults)
        manager.configure(user: User(id: UUID().uuidString, displayName: "Layout Test"))
        let state = GuideNavigationState()
        let appeared = expectation(description: "Navigation screen appeared")
        let firstTip = expectation(description: "Connect tip after content readiness")
        let secondTip = expectation(description: "Detail tip after navigation")
        var appearanceReported = false
        var firstReported = false
        var secondReported = false
        let generationObserver = manager.$presentationGeneration.dropFirst().sink { _ in
            if !appearanceReported {
                appearanceReported = true
                appeared.fulfill()
            }
        }
        let tipObserver = manager.$activeTip.compactMap { $0 }.sink { tip in
            if tip.target == .connectCard, !firstReported {
                firstReported = true
                firstTip.fulfill()
            }
            if tip.target == .communityJoin, !secondReported {
                secondReported = true
                secondTip.fulfill()
            }
        }
        let root = CLGuideHost(manager: manager) {
            GuideNavigationFixture(state: state)
        }.environment(\.scenePhase, .active)
        let controller = UIHostingController(rootView: root)
        let window = makeWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer {
            generationObserver.cancel()
            tipObserver.cancel()
            window.isHidden = true
            window.rootViewController = nil
        }
        await fulfillment(of: [appeared], timeout: 3)
        XCTAssertNil(manager.activeTip, "An appeared screen with loading content must not show a tip")
        state.ready = true
        await fulfillment(of: [firstTip], timeout: 3)
        state.showDetail = true
        await fulfillment(of: [secondTip], timeout: 3)
        XCTAssertEqual(manager.activeTip?.target, .communityJoin)
    }

    func testChatsToConnectWaitsForDestinationContent() async {
        let manager = ContextualGuideManager(repository: MockUserRepository())
        manager.configure(user: User(id: UUID().uuidString, displayName: "Tab Test"))
        let state = GuideNavigationState()
        let chats = expectation(description: "Chats tip")
        let connect = expectation(description: "Connect tip")
        var seen = Set<CLGuideTarget>()
        let observer = manager.$activeTip.compactMap { $0 }.sink { tip in
            guard seen.insert(tip.target).inserted else { return }
            if tip.target == .chatUnread { chats.fulfill() }
            if tip.target == .connectCard { connect.fulfill() }
        }
        let controller = UIHostingController(rootView:
            CLGuideHost(manager: manager) {
                GuideTabFixture(state: state, manager: manager)
            }.environment(\.scenePhase, .active)
        )
        let window = makeWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer {
            observer.cancel()
            window.isHidden = true
            window.rootViewController = nil
        }
        await fulfillment(of: [chats], timeout: 3)
        let switched = expectation(description: "Tab selection invalidates old geometry")
        let transitionObserver = manager.$presentationGeneration.dropFirst().prefix(1).sink { _ in
            switched.fulfill()
        }
        state.selectedTab = 1
        await fulfillment(of: [switched], timeout: 3)
        XCTAssertNil(manager.activeTip)
        XCTAssertFalse(seen.contains(.connectCard))
        state.ready = true
        await fulfillment(of: [connect], timeout: 3)
        XCTAssertEqual(manager.activeTip?.target, .connectCard)
        transitionObserver.cancel()
    }

    private func makeWindow(frame: CGRect) -> UIWindow {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("Hosting integration tests require the app's window scene")
            return UIWindow(frame: frame)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        return window
    }

    private func verifyLayout(size: CGSize, dynamicType: DynamicTypeSize) async {
        let tip = CLGuideTip.catalog[0]
        let viewport = CGRect(origin: .zero, size: size)
        let safe = viewport.insetBy(dx: 0, dy: 24)
        let target = CGRect(x: 32, y: 80, width: size.width - 64, height: size.height - 140)
        let measured = expectation(description: "Measured natural tooltip content")
        var measurements: [CGSize] = []
        let root = CLGuideOverlay(
            tip: tip, targetID: .init(.connectCard, instance: "layout-test"),
            target: target, viewport: viewport, safeBounds: safe,
            reduceMotion: true, onDismiss: {}
        )
        .ignoresSafeArea()
        .environment(\.dynamicTypeSize, dynamicType)
        .onPreferenceChange(CLGuideSizeKey.self) { value in
            guard value.width > 0, value.height > 0 else { return }
            measurements.append(value)
            if measurements.count == 1 { measured.fulfill() }
        }
        let controller = UIHostingController(rootView: root)
        let window = makeWindow(frame: viewport)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = viewport
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        await fulfillment(of: [measured], timeout: 3)
        guard let contentSize = measurements.last else { return }
        XCTAssertEqual(contentSize.width, min(340, size.width - 32), accuracy: 1)
        XCTAssertNotEqual(contentSize.height, size.height, "Must measure the card, not the position wrapper")
        let placement = CLGuidePlacementEngine.place(.init(
            target: target, viewport: viewport, safeBounds: safe,
            tooltipSize: contentSize, spacing: 16
        ))
        guard case let .bottomPanel(frame) = placement else {
            XCTFail("Large target should use the bottom panel")
            return
        }
        XCTAssertTrue(safe.contains(frame))
        if dynamicType == .accessibility5 {
            XCTAssertGreaterThan(contentSize.height, frame.height, "Long content must remain scrollable")
        }
        controller.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: viewport, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Guide-\(Int(size.width))x\(Int(size.height))-\(dynamicType)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class GuideNavigationState: ObservableObject {
    @Published var selectedTab = 0
    @Published var ready = false
    @Published var showDetail = false
}

private struct GuideNavigationFixture: View {
    @ObservedObject var state: GuideNavigationState

    var body: some View {
        NavigationStack {
            VStack {
                Text("Connect")
                    .frame(width: 200, height: 200)
                    .clGuideTarget(.connectCard, enabled: state.ready)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clGuideScreen(.connect)
            .navigationDestination(isPresented: $state.showDetail) {
                Text("Join")
                    .frame(width: 100, height: 44)
                    .clGuideTarget(.communityJoin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clGuideScreen(.communities)
            }
        }
    }
}

private struct GuideTabFixture: View {
    @ObservedObject var state: GuideNavigationState
    let manager: ContextualGuideManager

    var body: some View {
        TabView(selection: $state.selectedTab) {
            NavigationStack {
                Text("3 unread")
                    .frame(width: 100, height: 44)
                    .clGuideTarget(.chatUnread)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clGuideScreen(.chats)
            }
            .tabItem { Label("Chats", systemImage: "bubble") }
            .tag(0)
            NavigationStack {
                Text("Connect")
                    .frame(width: 200, height: 200)
                    .clGuideTarget(.connectCard, enabled: state.ready)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clGuideScreen(.connect)
            }
            .tabItem { Label("Connect", systemImage: "link") }
            .tag(1)
        }
        .onChange(of: state.selectedTab) { tab in manager.visit(tab == 0 ? .chats : .connect) }
    }
}
