import React, { PropTypes, Component } from 'react'
import _ from 'lodash'
import PublishAffix from './publish_affix'
import PublishSections from './publish_sections'

export default class BrandedPublishModal extends Component {
  render () {
    const { entries } = this.props
    const brandGuide = entries.brand_data.publish_guide_html
    const loopEntries = _.omit(entries, 'brand_data')
    return (
      <span>
        <div
          id='publish-table'
          className='modal-body-content row content-as-table'>
          <div className='col-md-12'>
            <div id='brand-guide'
              dangerouslySetInnerHTML={{__html: brandGuide}} />
            <br />
            <PublishSections entries={loopEntries}
              onSwitch={this.props.onSwitch} />
          </div>
        </div>
      </span>
    )
  }
}

BrandedPublishModal.propTypes = {
  entries: PropTypes.object.isRequired,
  initialEntry: PropTypes.object,
  onSwitch: PropTypes.func.isRequired
}
