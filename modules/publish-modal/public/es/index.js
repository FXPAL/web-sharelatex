import DestinationsError from './src/components/destinations_error'
import PublishModal from './src/components/publish_modal'
import ReactDOM from 'react-dom'
import React from 'react'

export function init(rootEl, initParams, publishModalConfig) {
  const getJournalsAndRender = (
    url,
    rootEl,
    initParams,
    brandVariationId,
    initialShown
  ) => {
    let props = {
      initialShown: initialShown,
      initParams: initParams,
      brandVariationId: brandVariationId
    }
    const showPublishModal = jsonResponse => {
      let entries = JSON.parse(jsonResponse)
      props.entries = entries
      ReactDOM.render(React.createElement(PublishModal, props), rootEl)
    }
    const aggregateProps = template => {
      props.initParams.description = template.description
      props.initParams.author = template.author
      props.initParams.license = template.license
    }
    // TODO create an error component to render here instead
    const showError = jsonResponse => {
      ReactDOM.render(React.createElement(DestinationsError, {}), rootEl)
    }
    const promiseAjaxGet = url => {
      return new Promise((resolve, reject) => {
        $.ajax({
          url: url,
          type: 'GET'
        })
          .done(resolve)
          .fail(reject)
      })
    }
    promiseAjaxGet(url)
      .then(jsonResponse => {
        let templateURL = `/latest_template/${initParams.projectId}`
        promiseAjaxGet(templateURL)
          .then(aggregateProps)
          .catch(e => {
            // retrieval of prior submission is not essential
          })
        return jsonResponse
      })
      .then(showPublishModal)
      .catch(showError)
  }

  const initBasic = (rootEl, initParams) => {
    const url = '/journals'
    getJournalsAndRender(url, rootEl, initParams, null, 'basic')
  }

  const initForBrand = (rootEl, initParams, brandId) => {
    const url = `/journals/${brandId}`
    getJournalsAndRender(url, rootEl, initParams, null, 'branded')
  }

  const initForGuide = (rootEl, initParams, brandId, brandVariationId) => {
    const url = `/journals/${brandId}`
    getJournalsAndRender(url, rootEl, initParams, brandVariationId, 'guide')
  }

  const initForExport = (rootEl, initParams, brandId, brandVariationId) => {
    const url = `/journals/${brandId}`
    getJournalsAndRender(url, rootEl, initParams, brandVariationId, 'export')
  }

  if (!publishModalConfig.isBranded) {
    initBasic(rootEl, initParams)
  } else if (publishModalConfig.brandedMenu) {
    initForBrand(rootEl, initParams, publishModalConfig.brandId)
  } else if (publishModalConfig.partner) {
    initForExport(
      rootEl,
      initParams,
      publishModalConfig.brandId,
      publishModalConfig.brandVariationId
    )
  } else {
    initForGuide(
      rootEl,
      initParams,
      publishModalConfig.brandId,
      publishModalConfig.brandVariationId
    )
  }
}
