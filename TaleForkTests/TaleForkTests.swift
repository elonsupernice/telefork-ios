import XCTest
@testable import TaleFork

final class StoryLibraryTests: XCTestCase {
    func testLibraryContainsOriginalBranchingStories() {
        XCTAssertGreaterThanOrEqual(StoryLibrary.stories.count, 3)

        for story in StoryLibrary.stories {
            XCTAssertFalse(story.title.zhHant.isEmpty)
            XCTAssertFalse(story.title.en.isEmpty)
            XCTAssertFalse(story.title.ja.isEmpty)
            XCTAssertNotNil(story.scene(id: story.entrySceneID))
            XCTAssertGreaterThanOrEqual(story.endings.count, 2)

            let sceneIDs = story.scenes.map(\.id)
            XCTAssertEqual(Set(sceneIDs).count, sceneIDs.count, "Duplicate scene ID in \(story.id)")

            for scene in story.scenes {
                if scene.ending == nil {
                    XCTAssertFalse(scene.choices.isEmpty, "Non-ending scene \(scene.id) has no choice")
                }
                for choice in scene.choices {
                    XCTAssertNotNil(
                        story.scene(id: choice.destinationSceneID),
                        "Choice \(choice.id) points to a missing scene"
                    )
                }
            }
        }
    }

    func testEverySceneIsReachableFromEntry() {
        for story in StoryLibrary.stories {
            var pending = [story.entrySceneID]
            var reached = Set<String>()
            while let sceneID = pending.popLast() {
                guard reached.insert(sceneID).inserted, let scene = story.scene(id: sceneID) else { continue }
                pending.append(contentsOf: scene.choices.map(\.destinationSceneID))
            }
            XCTAssertEqual(reached, Set(story.scenes.map(\.id)), "Unreachable scene in \(story.id)")
        }
    }

    func testLocalizationKeySetsMatch() throws {
        var baseline: Set<String>?
        for language in ["en", "ja", "zh-Hant"] {
            let lproj = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let path = URL(fileURLWithPath: lproj).appendingPathComponent("Localizable.strings").path
            let dictionary = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            let keys = Set(dictionary.keys)
            XCTAssertGreaterThan(keys.count, 40)
            if let baseline {
                XCTAssertEqual(keys, baseline, "Localization keys differ for \(language)")
            } else {
                baseline = keys
            }
        }
    }
}

@MainActor
final class ProgressStoreTests: XCTestCase {
    func testChoiceProgressAndPersistenceRoundTrip() throws {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let story = try XCTUnwrap(StoryLibrary.stories.first)
        let firstScene = try XCTUnwrap(story.scene(id: story.entrySceneID))
        let choice = try XCTUnwrap(firstScene.choices.first)
        let store = ProgressStore(defaults: defaults)

        store.start(story)
        store.choose(choice, in: story)

        XCTAssertEqual(store.run(for: story).currentSceneID, choice.destinationSceneID)
        XCTAssertEqual(store.run(for: story).visitedSceneIDs.count, 2)

        let restored = ProgressStore(defaults: defaults)
        XCTAssertEqual(restored.run(for: story), store.run(for: story))
    }

    func testRestartKeepsUnlockedEndings() throws {
        let story = try XCTUnwrap(StoryLibrary.stories.first)
        var run = StoryRun(story: story)
        var safety = 0
        while story.scene(id: run.currentSceneID)?.ending == nil, safety < 20 {
            let scene = try XCTUnwrap(story.scene(id: run.currentSceneID))
            run.choose(try XCTUnwrap(scene.choices.first), in: story)
            safety += 1
        }
        XCTAssertFalse(run.completedEndingIDs.isEmpty)
        let endings = run.completedEndingIDs

        run.restart(with: story)
        XCTAssertEqual(run.currentSceneID, story.entrySceneID)
        XCTAssertEqual(run.visitedSceneIDs, [story.entrySceneID])
        XCTAssertEqual(run.completedEndingIDs, endings)
    }

    func testQuoteToggleAndReset() throws {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let story = try XCTUnwrap(StoryLibrary.stories.first)
        let scene = try XCTUnwrap(story.scenes.first)
        let store = ProgressStore(defaults: defaults)

        store.toggleQuote(storyID: story.id, sceneID: scene.id, text: "A saved line")
        XCTAssertTrue(store.isQuoteSaved(storyID: story.id, sceneID: scene.id))
        XCTAssertEqual(store.savedQuotes.count, 1)

        store.toggleQuote(storyID: story.id, sceneID: scene.id, text: "A saved line")
        XCTAssertFalse(store.isQuoteSaved(storyID: story.id, sceneID: scene.id))

        store.start(story)
        store.resetAllProgress()
        XCTAssertTrue(store.runs.isEmpty)
        XCTAssertTrue(store.savedQuotes.isEmpty)
    }

    private func makeDefaults() -> (String, UserDefaults) {
        let suiteName = "TaleForkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }
}
