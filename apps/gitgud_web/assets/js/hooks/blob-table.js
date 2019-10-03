import React from "react"
import ReactDOM from "react-dom"

import {BlobTableHeader} from "../components"

export default () => {
  const blob = document.getElementById("blob")
  if(blob) {
    const {repoId, commitOid, blobPath} = blob.dataset
    BlobTableHeader.fetchTreeEntryWithCommit(repoId, commitOid, blobPath)
      .then(response => {
        const {commit} = response.node.object.treeEntryWithLastCommit
        const container = document.createElement("div")
        blob.replaceChild(container, blob.firstElementChild)
        ReactDOM.render(React.createElement(BlobTableHeader, {commit: commit}), container)
      })
  }
}
