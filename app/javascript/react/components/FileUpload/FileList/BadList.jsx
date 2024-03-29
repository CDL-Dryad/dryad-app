import React from 'react';

// checks files to see if they have validation and also status
const filterForStatus = (status, files) => {
  const fns = files.map((file) => {
    if (!Object.prototype.hasOwnProperty.call(file, 'frictionless_report')) return null;

    if (file.frictionless_report?.status === status) return file.upload_file_name;

    return null;
  });

  // only return non-null
  return fns.filter((n) => n);
};

const makeAndString = (arr) => {
  if (arr.length === 0) return '';
  if (arr.length === 1) return arr[0];
  const firsts = arr.slice(0, arr.length - 1);
  const last = arr[arr.length - 1];
  return `${firsts.join(', ')} and ${last}`;
};

const badList = (props) => {
  const errorFiles = filterForStatus('error', props.chosenFiles);
  const issueFiles = filterForStatus('issues', props.chosenFiles);
  if (errorFiles.length + issueFiles.length < 1) return (null);

  let errorMsg = '';
  let issueMsg = '';

  if (errorFiles.length > 0) {
    errorMsg = (
      <div className="c-alert__text-lite">
        Our tabular data checker couldn&apos;t read tabular data from {makeAndString(errorFiles)}.
        If you expect them to have consistent tabular data, check that they are readable and formatted correctly.
      </div>
    );
  }

  if (issueFiles.length > 0) {
    issueMsg = (
      <div>
        <span className="c-alert__text-lite">
          Our automated tabular data checker identified potential inconsistencies in the format and structure of {issueFiles.length} of your files.
        </span>
        <p>
          <a href="/stash/data_check_guide" target="_blank">
            A detailed report is available<span className="screen-reader-only"> (opens in new window)</span>
          </a>
          {' '}for each file. To address the identified alerts:
        </p>
        <ol>
          <li>
            Click the alert button in the
            {' '}<em>Tabular data check</em>{' '}
            column to see what has been highlighted for your review.
          </li>
          <li>Review the local copy of your file and make any desired changes.</li>
          <li>
            If you would like to replace the file, click &quot;Remove&quot; in the <em>Actions</em> column to delete the current upload.
          </li>
          <li>
            Re-upload the corrected file using the &quot;Choose files&quot; or &quot;Enter URLs&quot; button above.
          </li>
        </ol>
      </div>
    );
  }

  return (
    <div className="js-alert c-alert--error-lite" role="alert">
      <div className="c-alert__text">
        {errorMsg}
        {issueMsg}
      </div>
      <button type="button" aria-label="close" className="js-alert__close o-button__close-lite c-alert__close-lite" />
    </div>
  );
};

export default badList;
