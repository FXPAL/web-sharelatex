/* global sinon */

import React from 'react'
import {
  render,
  fireEvent,
  cleanup,
  waitForElement
} from 'react-testing-library'

import PublishGuide from 'Modules/publish-modal/public/es/src/components/publish_guide'

describe('<PublishGuide />', function() {
  let ajaxStub

  this.timeout(5000)

  beforeEach(() => {
    window.ExposedSettings = { siteUrl: 'http://example.com' }
  })

  afterEach(() => {
    delete window.ExposedSettings
    cleanup()
  })

  describe('successful start export request', () => {
    beforeEach(() => {
      // Mock export initial POST request to be successful
      ajaxStub = sinon
        .stub($, 'ajax')
        .onFirstCall()
        .returns($.Deferred().resolve({ export_v1_id: 3 }))
    })

    afterEach(() => {
      $.ajax.restore()
    })

    it('waits for download poll to succeed', () => {
      // Mock poll request to succeed
      ajaxStub
        .onSecondCall()
        .returns(
          $.Deferred().resolve({ export_json: { status_summary: 'succeeded' } })
        )
      const { getByText } = renderPublishGuide()

      const downloadButton = getByText(/download project zip/i)
      fireEvent.click(downloadButton)

      return waitForElement(() => getByText(/compiling project, please wait/i))
        .then(pollingText => {
          // Has started polling
          expect(pollingText).to.exist

          return waitForElement(() => getByText(/download project zip/i))
        })
        .then(resetDownloadButton => {
          // Has reset back to uninitiated
          expect(resetDownloadButton).to.exist
        })
    })

    it('keeps polling until success polling response is received', () => {
      ajaxStub
        // Mock first poll request to be still pending
        .onSecondCall()
        .returns($.Deferred().resolve({ export_json: {} }))
        // Mock second poll request to succeed
        .onThirdCall()
        .returns(
          $.Deferred().resolve({ export_json: { status_summary: 'succeeded' } })
        )
      const { getByText } = renderPublishGuide()

      const downloadButton = getByText(/download project zip/i)
      fireEvent.click(downloadButton)

      return waitForElement(() => getByText(/compiling project, please wait/i))
        .then(pollingText => {
          // Has started polling
          expect(pollingText).to.exist

          return waitForElement(() => getByText(/download project zip/i))
        })
        .then(resetDownloadButton => {
          // Has reset back to uninitiated
          expect(resetDownloadButton).to.exist
        })
    })

    it('triggers file download after completed export', () => {
      // Mock poll request to succeed
      ajaxStub
        .onSecondCall()
        .returns(
          $.Deferred().resolve({ export_json: { status_summary: 'succeeded' } })
        )
      const downloadFile = sinon.spy()
      const { getByText } = renderPublishGuide({ downloadFile })

      const downloadButton = getByText(/download project zip/i)
      fireEvent.click(downloadButton)

      return waitForElement(() => getByText(/download project zip/i)).then(
        () => {
          expect(downloadFile).to.have.been.called
        }
      )
    })

    it('shows error on polling error response', () => {
      // Mock first poll request to fail
      ajaxStub.onSecondCall().returns($.Deferred().reject(new Error()))
      const { getByText } = renderPublishGuide()

      const downloadButton = getByText(/download project zip/i)
      fireEvent.click(downloadButton)

      return waitForElement(() => getByText(/compiling project, please wait/i))
        .then(pollingText => {
          // Has started polling
          expect(pollingText).to.exist

          return waitForElement(() => getByText(/project failed to compile/i))
        })
        .then(errorMessage => {
          // Has shown error message
          expect(errorMessage).to.exist
        })
    })

    it('shows error on successful polling response with failed message', () => {
      // Mock first poll request to succeed, but with failed message
      ajaxStub
        .onSecondCall()
        .returns(
          $.Deferred().resolve({ export_json: { status_summary: 'failed' } })
        )
      const { getByText } = renderPublishGuide()

      const downloadButton = getByText(/download project zip/i)
      fireEvent.click(downloadButton)

      return waitForElement(() => getByText(/compiling project, please wait/i))
        .then(pollingText => {
          // Has started polling
          expect(pollingText).to.exist

          return waitForElement(() => getByText(/project failed to compile/i))
        })
        .then(errorMessage => {
          // Has shown error message
          expect(errorMessage).to.exist
        })
    })
  })
})

function renderPublishGuide(args) {
  const props = Object.assign(
    {},
    {
      returnText: 'Return',
      entry: {
        id: 2,
        publish_guide_html: 'Some HTML',
        publish_link_destination: 'http://example.com'
      },
      onReturn: () => {},
      projectId: '1',
      downloadFile: () => {}
    },
    args
  )

  return render(<PublishGuide {...props} />)
}
