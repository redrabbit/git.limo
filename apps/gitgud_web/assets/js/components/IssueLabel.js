import React from "react"

class IssueLabel extends React.Component {
  static textClass(color) {
		const threshold = 130
		const hRed = parseInt(color.substring(0,2), 16)
		const hGreen = parseInt(color.substring(2,4), 16)
		const hBlue = parseInt(color.substring(4,6), 16)
		const cBrightness = ((hRed * 299) + (hGreen * 587) + (hBlue * 114)) / 1000
    return cBrightness > threshold ? "has-text-dark" : "has-text-light"
  }

  render() {
    const {name, color, edit, active, onToggle} = this.props
    const textClass = this.constructor.textClass(color)
    if(edit) {
      if(active) {
        return (
          <button className={`button issue-label edit is-active ${textClass}`} style={{backgroundColor: `#${color}`}} onClick={onToggle}>
            {edit &&
              <span className="icon is-small is-pulled-right">
                <i className="fa fa-minus"></i>
              </span>
            }
            {name}
          </button>
        )
      } else {
        return <button className="button issue-label edit" onClick={onToggle}>{name}</button>
      }
    } else {
      return <button className={`button ${textClass} issue-label is-active`} style={{backgroundColor: `#${color}`}} onClick={onToggle}>{name}</button>
    }
  }
}

export default IssueLabel
