import React, { PropTypes, Component } from 'react'
import ReturnButton from './return_button'

export default class PublishGuide extends Component {
  render () {
    const { entry, returnText, onReturn, projectId, pdfUrl } = this.props

    return (
      <div
        className='publish-guide modal-body-content row content-as-table'
        id={'publish-guide-' + entry.id}
        key={entry.id}
      >
        <div className='col-sm-12'>
          <ReturnButton onReturn={onReturn} returnText={returnText} />
          <GuideHtml entry={entry} projectId={projectId} pdfUrl={pdfUrl} />
          {entry.publish_link_destination &&
           <div>
             <Download entry={entry} projectId={projectId} pdfUrl={pdfUrl} />
             <Submit entry={entry} />
           </div>}
        </div>
      </div>
    )
  }
}

export function GuideHtml ({ entry, projectId, pdfUrl }) {
  const html = entry.publish_guide_html
  if (html.indexOf('DOWNLOAD') !== -1) {
    const htmlParts = html.split('DOWNLOAD')
    return (
      <div>
        <div dangerouslySetInnerHTML={{ __html: htmlParts[0] }} />
        <Download entry={entry} projectId={projectId} pdfUrl={pdfUrl} />
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

function Download ({ entry, projectId, pdfUrl }) {
  return (
    <div style={{ marginLeft: '140px', paddingLeft: '15px' }}>
      { /* Most publish guides have an image column
           with 140px as the set width */ }
      <p><strong>Step 1: Download files</strong></p>
      <p>
        <a
          className="btn btn-primary"
          href={'/project/' + projectId + '/download/zip'}
          target="_blank"
        >
          Download ZIP file with all the source files
        </a>
      </p>
      <p>
        {pdfUrl &&
         <a
           className="btn btn-primary"
           href={pdfUrl}
           target="_blank">
           Download PDF file of your article
         </a>}
        {!pdfUrl && <a className="btn btn-primary disabled" disabled>
          Download PDF file of your article
          ( please compile your project before downloading PDF )
        </a>}
      </p>
    </div>
  )
}

function Submit ({ entry }) {
  return (
    <div style={{ marginLeft: '140px', paddingLeft: '15px' }}>
      <p><strong>Step 2: Submit your manuscript</strong></p>
      <p>
        <a
          href={entry.publish_link_destination}
          target='_blank'
          rel='noopener'
          className='btn btn-primary'
          data-event='link_submit'
          data-category='Publish'
          data-action='submit'
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
  projectId: PropTypes.string.isRequired,
  pdfUrl: PropTypes.string
}

GuideHtml.propTypes = {
  entry: PropTypes.object.isRequired,
  projectId: PropTypes.string.isRequired,
  pdfUrl: PropTypes.string
}

Download.propTypes = {
  entry: PropTypes.object.isRequired,
  projectId: PropTypes.string.isRequired,
  pdfUrl: PropTypes.string
}

Submit.propTypes = {
  entry: PropTypes.object.isRequired
}
