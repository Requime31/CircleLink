import SwiftUI
import UIKit
import XCTest
@testable import CircleLink

@MainActor
final class ConnectTutorialLayoutTests: XCTestCase {
    func testPracticeStepFitsNarrowScreenAtLargeText() {
        let tutorial = ConnectTutorialController()
        tutorial.start()
        tutorial.demonstrationFinished(.pass)

        render(
            tutorial: tutorial,
            size: CGSize(width: 320, height: 568),
            dynamicType: .accessibility2,
            attachmentName: "Connect tutorial — practice pass"
        )
    }

    func testReadyStepFitsStandardScreen() {
        let tutorial = ConnectTutorialController()
        tutorial.start()
        tutorial.demonstrationFinished(.pass)
        tutorial.practiceCompleted(.pass)
        tutorial.demonstrationFinished(.sayHi)
        tutorial.practiceCompleted(.sayHi)

        render(
            tutorial: tutorial,
            size: CGSize(width: 390, height: 844),
            dynamicType: .large,
            attachmentName: "Connect tutorial — ready"
        )
    }

    private func render(
        tutorial: ConnectTutorialController,
        size: CGSize,
        dynamicType: DynamicTypeSize,
        attachmentName: String
    ) {
        let user = User(
            id: "tutorial-user",
            displayName: "Taylor",
            interests: ["Music", "Art", "Travel"],
            age: 27,
            aboutMe: "Always looking for the next good concert."
        )
        let root = ConnectDiscoverDeckView(
            top: user,
            next: nil,
            following: nil,
            communities: [],
            isSendingConnect: false,
            tutorial: tutorial,
            onCompleteTutorial: {},
            onPass: { _ in XCTFail("Tutorial must not pass a real candidate") },
            onSayHi: { _ in
                XCTFail("Tutorial must not send a real connection request")
                return false
            }
        )
        .environment(\.dynamicTypeSize, dynamicType)

        let controller = UIHostingController(rootView: root)
        let window = makeWindow(size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertEqual(controller.view.bounds.size.width, size.width, accuracy: 1)
        XCTAssertEqual(controller.view.bounds.size.height, size.height, accuracy: 1)
        XCTAssertEqual(tutorial.phase == .ready ? .ready : .practicingPass, tutorial.phase)

        let image = UIGraphicsImageRenderer(size: size).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeWindow(size: CGSize) -> UIWindow {
        let frame = CGRect(origin: .zero, size: size)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            XCTFail("A window scene is required")
            return UIWindow(frame: frame)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        return window
    }
}
