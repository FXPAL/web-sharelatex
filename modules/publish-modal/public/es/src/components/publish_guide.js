import React, { PropTypes, Component } from 'react'
import ReturnButton from './return_button'
import { initiateExport } from '../utils'

export default class PublishGuide extends Component {
  constructor(props) {
    super(props)
    this.state = {
      exportState: 'uninitiated',
      exportId: null,
      downloadRequested: null
    }
  }

  componentDidUpdate() {
    if (this.state.exportState === 'complete') {
      var link = `/project/${this.props.projectId}/export/${
        this.state.exportId
      }/`
      if (this.state.downloadRequested === 'zip') {
        link = link + 'zip'
      } else {
        link = link + 'pdf'
      }
      window.location = link
      // eslint-disable-next-line react/no-did-update-set-state
      this.setState({ exportState: 'uninitiated' })
    }
  }

  initiateGuideExport(entry, projectId, _this, type) {
    this.setState({ downloadRequested: type })
    initiateExport(entry, projectId, _this)
  }

  render() {
    const { entry, returnText, onReturn, projectId } = this.props

    return (
      <div
        className="publish-guide modal-body-content row content-as-table"
        id={'publish-guide-' + entry.id}
        key={entry.id}
      >
        <div className="col-sm-12">
          <ReturnButton onReturn={onReturn} returnText={returnText} />
          <GuideHtml entry={entry} projectId={projectId} _this={this} />
          {entry.publish_link_destination && (
            <div>
              <Download entry={entry} projectId={projectId} _this={this} />
              <Submit entry={entry} />
            </div>
          )}
        </div>
      </div>
    )
  }
}

export function GuideHtml({ entry, projectId, _this }) {
  const html = entry.publish_guide_html
  if (html.indexOf('DOWNLOAD') !== -1) {
    const htmlParts = html.split('DOWNLOAD')
    return (
      <div>
        <div dangerouslySetInnerHTML={{ __html: htmlParts[0] }} />
        <Download entry={entry} projectId={projectId} _this={_this} />
        <div
          style={{ marginLeft: '140px', paddingLeft: '15px' }}
          dangerouslySetInnerHTML={{ __html: htmlParts[1] }}
        />
      </div>
    )
  } else {
    return (
      <div dangerouslySetInnerHTML={{ __html: entry.publish_guide_html }} />
    )
  }
}

function Download({ entry, projectId, _this }) {
  return (
    <div style={{ marginLeft: '140px', paddingLeft: '15px' }}>
      {/* Most publish guides have an image column
           with 140px as the set width */}
      <p>
        <strong>Step 1: Download files</strong>
      </p>
      {_this.state.exportState === 'uninitiated' && (
        <span>
          <p>
            <button
              className="btn btn-primary"
              onClick={() =>
                _this.initiateGuideExport(entry, projectId, _this, 'zip')
              }
            >
              Download project ZIP with submission files (e.g. .bbl)
            </button>
          </p>
          <p>
            <button
              className="btn btn-primary"
              onClick={() =>
                _this.initiateGuideExport(entry, projectId, _this, 'pdf')
              }
            >
              Download PDF file of your article
            </button>
          </p>
        </span>
      )}
      {_this.state.exportState === 'initiated' && (
        <p style={{ fontSize: 20, margin: '20px 0px 20px' }}>
          <i className="fa fa-refresh fa-spin fa-fw" />
          <span> &nbsp; Compiling project, please wait...</span>
        </p>
      )}
      {_this.state.exportState === 'error' && (
        <p>
          Project failed to compile
          <br />
          Error message: {_this.state.errorDetails}
        </p>
      )}
    </div>
  )
}

function Submit({ entry }) {
  return (
    <div style={{ marginLeft: '140px', paddingLeft: '15px' }}>
      <p>
        <strong>Step 2: Submit your manuscript</strong>
      </p>
      <p>
        <a
          href={entry.publish_link_destination}
          target="_blank"
          rel="noopener"
          className="btn btn-primary"
          data-event="link_submit"
          data-category="Publish"
          data-action="submit"
          data-label={entry.id}
        >
          Submit to {entry.name}
        </a>
      </p>
    </div>
  )
}

PublishGuide.propTypes = {
  entry: PropTypes.object.isRequired,
  returnText: PropTypes.string,
  onReturn: PropTypes.func,
  projectId: PropTypes.string.isRequired
}

GuideHtml.propTypes = {
  entry: PropTypes.object.isRequired,
  projectId: PropTypes.string.isRequired,
  _this: PropTypes.object.isRequired
}

Download.propTypes = {
  entry: PropTypes.object.isRequired,
  projectId: PropTypes.string.isRequired,
  _this: PropTypes.object.isRequired
}

Submit.propTypes = {
  entry: PropTypes.object.isRequired
}