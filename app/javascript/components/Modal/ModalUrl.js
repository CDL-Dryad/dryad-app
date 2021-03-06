import React from 'react';
import ValidateFiles from "../ValidateFiles/ValidateFiles";

const modal_url = (props) => {
    return (
        <div>
            <dialog id="js-uploadmodal"
                    className="c-uploadmodal"
                    style={{
                        'width': '60%', 'height': '370px', 'max-width': '750px', 'min-width': '220px',
                        'z-index': '100149', 'top': '50%'}}
                    open>
                <form method='dialog' onSubmit={(event) => props.submitted(event)}>
                    <div className="c-uploadmodal__header">
                        <label className="c-uploadmodal__textarea-url-label" htmlFor="location_urls">Enter
                            URLs</label>
                        <button className="c-uploadmodal__button-close-modal js-uploadmodal__button-close-modal"
                                aria-label="close"
                                type="button"
                                onClick={(event) => props.clickedClose(event)} />
                    </div>
                    <textarea id="location_urls" className="c-uploadmodal__textarea-url" name="url"
                              onChange={props.changedUrls}
                              placeholder="List file location URLs here" />
                    <div className="c-uploadmodal__text-content">Place each URL on a new line.</div>
                    <ValidateFiles
                        id='confirm_to_validate'
                        buttonLabel='Validate Files'
                        checkConfirmed={false}
                        disabled={false} />
                </form>
            </dialog>
            <div className="backdrop" style={{'z-index': '100148'}} />
        </div>
    );
}

export default modal_url;