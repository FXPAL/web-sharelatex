import React, { PropTypes, Component } from 'react'
import BasicPublishModal from './basic_publish_modal'
import BrandedPublishModal from './branded_publish_modal'
import GuidePublishModal from './guide_publish_modal'
import { findEntryInCategories } from '../utils.js'

export default class PublishModal extends Component {
  constructor(props) {
    super(props)
    this.state = {
      shown: props.initialShown,
      baseReturn: props.initialShown
    }
    this.handleSwitch = this.handleSwitch.bind(this)

    // if we want to start at a guide or export we need to find it and
    // see if it gets a back button
    if (props.initialShown === 'guide' || props.initialShown === 'export') {
      this.state.initialEntry = findEntryInCategories(
        props.entries,
        props.brandVariationId
      )
      this.state.guideId = this.state.initialEntry.id
      this.state.baseReturn = 'branded'
    }
  }

  handleSwitch(switchTo, guideId) {
    if (switchTo) {
      this.setState({ shown: switchTo, guideId: guideId })
    } else {
      this.setState({
        shown: this.state.baseReturn,
        guideId: null
      })
    }
  }

  render() {
    const { entries, initParams } = this.props

    if (this.state.shown === 'basic') {
      return (
        <BasicPublishModal
          entries={this.props.entries}
          onSwitch={this.handleSwitch}
        />
      )
    }
    if (
      this.state.shown === 'guide' ||
      this.state.shown === 'exportGuide' ||
      this.state.shown === 'export'
    ) {
      return (
        <GuidePublishModal
          onSwitch={this.handleSwitch}
          entries={entries}
          guideId={this.state.guideId}
          initParams={initParams}
          shown={this.state.shown}
          initialEntry={this.state.initialEntry}
        />
      )
    } else if (this.state.shown === 'branded') {
      return (
        <BrandedPublishModal
          onSwitch={this.handleSwitch}
          entries={entries}
          initialEntry={this.state.initialEntry}
          initParams={initParams}
        />
      )
    }
  }
}

PublishModal.propTypes = {
  entries: PropTypes.object.isRequired,
  initialShown: PropTypes.string.isRequired,
  initParams: PropTypes.object.isRequired,
  brandVariationId: PropTypes.number
}
