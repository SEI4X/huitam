import XCTest
@testable import huitam

@MainActor
final class StudyCardsViewModelTests: XCTestCase {
    func testLoadCardsAndFilterByType() async {
        let service = RecordingStudyCardService()
        let viewModel = StudyCardsViewModel(studyCardService: service)

        await viewModel.load()
        viewModel.selectedFilter = .phrase

        XCTAssertEqual(viewModel.visibleCards.map(\.type), [.phrase])
    }
}
