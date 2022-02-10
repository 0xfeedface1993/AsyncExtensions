//
//  AsyncStreams+PassthroughTests.swift
//
//
//  Created by Thibault Wittemberg on 10/01/2022.
//

@testable import AsyncExtensions
import XCTest

private struct MockError: Error, Equatable {
    let code: Int
}

final class AsyncStreams_PassthroughTests: XCTestCase {
    func testSend_pushes_values_in_the_asyncSequence() {
        let isReadyToBeIteratedExpectation = expectation(description: "Passthrough subject iterators are ready for iteration")
        isReadyToBeIteratedExpectation.expectedFulfillmentCount = 2

        let hasReceivedSentElementsExpectation = expectation(description: "Send pushes elements in created AsyncSequences")
        hasReceivedSentElementsExpectation.expectedFulfillmentCount = 2

        let expectedResult = [1, 2, 3]

        let sut = AsyncStreams.Passthrough<Int>()

        Task {
            var receivedElements = [Int]()

            var it = sut.makeAsyncIterator()
            isReadyToBeIteratedExpectation.fulfill()
            while let element = try await it.next() {
                receivedElements.append(element)
                if element == 3 {
                    XCTAssertEqual(receivedElements, expectedResult)
                    hasReceivedSentElementsExpectation.fulfill()
                }
            }
        }

        Task {
            var receivedElements = [Int]()

            var it = sut.makeAsyncIterator()
            isReadyToBeIteratedExpectation.fulfill()
            while let element = try await it.next() {
                receivedElements.append(element)
                if element == 3 {
                    XCTAssertEqual(receivedElements, expectedResult)
                    hasReceivedSentElementsExpectation.fulfill()
                }
            }
        }

         wait(for: [isReadyToBeIteratedExpectation], timeout: 1)

        Task {
            await sut.send(1)
            await sut.send(2)
            await sut.send(3)
        }

        wait(for: [hasReceivedSentElementsExpectation], timeout: 1)
    }

    func testSendFinished_ends_the_asyncSequence_and_clear_internal_data() {
        let isReadyToBeIteratedExpectation = expectation(description: "Passthrough subject iterators are ready for iteration")
        isReadyToBeIteratedExpectation.expectedFulfillmentCount = 2

        let hasReceivedOneElementExpectation = expectation(description: "One element has been iterated in the async sequence")
        hasReceivedOneElementExpectation.expectedFulfillmentCount = 2

        let hasFinishedExpectation = expectation(description: "Send(.finished) finishes all created AsyncSequences")
        hasFinishedExpectation.expectedFulfillmentCount = 2

        let sut = AsyncStreams.Passthrough<Int>()

        Task {
            var it = sut.makeAsyncIterator()
            isReadyToBeIteratedExpectation.fulfill()
            while let element = try await it.next() {
                if element == 1 {
                    hasReceivedOneElementExpectation.fulfill()
                }
            }
            hasFinishedExpectation.fulfill()
        }

        Task {
            var it = sut.makeAsyncIterator()
            isReadyToBeIteratedExpectation.fulfill()
            while let element = try await it.next() {
                if element == 1 {
                    hasReceivedOneElementExpectation.fulfill()
                }
            }
            hasFinishedExpectation.fulfill()
        }

        wait(for: [isReadyToBeIteratedExpectation], timeout: 1)

        sut.nonBlockingSend(1)

        wait(for: [hasReceivedOneElementExpectation], timeout: 1)

        sut.nonBlockingSend(termination: .finished)

        wait(for: [hasFinishedExpectation], timeout: 1)
    }

    func testSendFailure_ends_the_asyncSequence_with_an_error_and_clear_internal_data() {
        let isReadyToBeIteratedExpectation = expectation(description: "Passthrough subject iterators are ready for iteration")
        isReadyToBeIteratedExpectation.expectedFulfillmentCount = 2

        let hasReceivedOneElementExpectation = expectation(description: "One element has been iterated in the async sequence")
        hasReceivedOneElementExpectation.expectedFulfillmentCount = 2

        let hasFinishedWithFailureExpectation = expectation(description: "Send(.failure) finishes all created AsyncSequences with error")
        hasFinishedWithFailureExpectation.expectedFulfillmentCount = 2

        let expectedError = MockError(code: Int.random(in: 0...100))

        let sut = AsyncStreams.Passthrough<Int>()

        Task {
            do {
                var it = sut.makeAsyncIterator()
                isReadyToBeIteratedExpectation.fulfill()
                while let element = try await it.next() {
                    if element == 1 {
                        hasReceivedOneElementExpectation.fulfill()
                    }
                }
            } catch {
                XCTAssertEqual(error as? MockError, expectedError)
                hasFinishedWithFailureExpectation.fulfill()
            }
        }

        Task {
            do {
                var it = sut.makeAsyncIterator()
                isReadyToBeIteratedExpectation.fulfill()
                while let element = try await it.next() {
                    if element == 1 {
                        hasReceivedOneElementExpectation.fulfill()
                    }
                }
            } catch {
                XCTAssertEqual(error as? MockError, expectedError)
                hasFinishedWithFailureExpectation.fulfill()
            }
        }

        wait(for: [isReadyToBeIteratedExpectation], timeout: 1)

        sut.nonBlockingSend(1)

        wait(for: [hasReceivedOneElementExpectation], timeout: 1)

        sut.nonBlockingSend(termination: .failure(expectedError))

        wait(for: [hasFinishedWithFailureExpectation], timeout: 1)
    }

    func testPassthrough_finishes_when_task_is_cancelled() {
        let isReadyToBeIteratedExpectation = expectation(description: "Passthrough subject iterators are ready for iteration")
        let canCancelExpectation = expectation(description: "The first element has been emitted")
        let hasCancelExceptation = expectation(description: "The task has been cancelled")
        let taskHasFinishedExpectation = expectation(description: "The task has finished")

        let sut = AsyncStreams.Passthrough<Int>()

        let task = Task {
            var receivedElements = [Int]()

            var it = sut.makeAsyncIterator()
            isReadyToBeIteratedExpectation.fulfill()
            while let element = try await it.next() {
                receivedElements.append(element)
                canCancelExpectation.fulfill()
                wait(for: [hasCancelExceptation], timeout: 5)
            }
            XCTAssertEqual(receivedElements, [1])
            taskHasFinishedExpectation.fulfill()
        }

        wait(for: [isReadyToBeIteratedExpectation], timeout: 1)

        sut.nonBlockingSend(1)

        wait(for: [canCancelExpectation], timeout: 5) // one element has been emitted, we can cancel the task

        task.cancel()

        hasCancelExceptation.fulfill() // we can release the lock in the for loop

        wait(for: [taskHasFinishedExpectation], timeout: 5) // task has been cancelled and has finished
    }

    func testPassthough_handles_concurrency() async throws {
        let canSendExpectation = expectation(description: "Passthrough is ready to be sent values")
        canSendExpectation.expectedFulfillmentCount = 2

        let expectedElements = (0...2000).map { $0 }

        let sut = AsyncStreams.Passthrough<Int>()

        // concurrently iterate the sut 1
        let taskA = Task { () -> [Int] in
            var received = [Int]()
            var iterator = sut.makeAsyncIterator()
            canSendExpectation.fulfill()
            while let element = try await iterator.next() {
                received.append(element)
            }
            return received.sorted()
        }

        // concurrently iterate the sut 2
        let taskB = Task { () -> [Int] in
            var received = [Int]()
            var iterator = sut.makeAsyncIterator()
            canSendExpectation.fulfill()
            while let element = try await iterator.next() {
                received.append(element)
            }
            return received.sorted()
        }

        await waitForExpectations(timeout: 1)

        // concurrently push values in the sut 1
        let task1 = Task {
            for index in (0...1000) {
                await sut.send(index)
            }
        }

        // concurrently push values in the sut 2
        let task2 = Task {
            for index in (1001...2000) {
                await sut.send(index)
            }
        }

        await task1.value
        await task2.value

        await sut.send(termination: .finished)

        let receivedElementsA = try await taskA.value
        let receivedElementsB = try await taskB.value

        XCTAssertEqual(receivedElementsA, expectedElements)
        XCTAssertEqual(receivedElementsB, expectedElements)
    }
}
