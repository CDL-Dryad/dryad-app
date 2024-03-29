import React from 'react';
import {render, screen, waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {faker} from '@faker-js/faker';
import axios from 'axios';
import Funders from '../../../../../app/javascript/react/components/MetadataEntry/Funders';

jest.mock('axios');

describe('Funders', () => {
  let contributors; let resourceId; let createPath; let updatePath; let deletePath; let
    reorderPath;

  beforeEach(() => {
    resourceId = faker.datatype.number();
    contributors = [];
    // add 3 contributors
    for (let i = 0; i < 3; i += 1) {
      contributors.push(
        {
          id: faker.datatype.number(),
          contributor_name: faker.company.companyName(),
          contributor_type: 'funder',
          identifier_type: null,
          name_identifier_id: null,
          resourceId,
          award_number: faker.datatype.string(5),
          award_description: faker.datatype.string(10),
          funder_order: i,
        },
      );
    }

    createPath = faker.system.directoryPath();
    updatePath = faker.system.directoryPath();
    deletePath = faker.system.directoryPath();
    reorderPath = faker.system.directoryPath();
  });

  it('renders multiple funder forms as funder section', () => {
    render(<Funders
      contributors={contributors}
      resourceId={resourceId}
      createPath={createPath}
      updatePath={updatePath}
      deletePath={deletePath}
      reorderPath={reorderPath}
    />);

    const labeledElements = screen.getAllByLabelText('Granting organization', {exact: false});
    expect(labeledElements.length).toBe(9); // three for each autocomplete list
    const awardNums = screen.getAllByLabelText('Award number', {exact: false});
    expect(awardNums.length).toBe(3);
    expect(awardNums[0]).toHaveValue(contributors[0].award_number);
    expect(awardNums[2]).toHaveValue(contributors[2].award_number);

    expect(screen.getByText('Add another funder')).toBeInTheDocument();
  });

  it('removes a funder from the document', async () => {
    const promise = Promise.resolve({
      status: 200,
      data: contributors[2],
    });

    axios.delete.mockImplementationOnce(() => promise);

    render(<Funders
      contributors={contributors}
      resourceId={resourceId}
      createPath={createPath}
      updatePath={updatePath}
      deletePath={deletePath}
      reorderPath={reorderPath}
    />);

    let removes = screen.getAllByText('remove');
    expect(removes.length).toBe(3);

    userEvent.click(removes[2]);

    await waitFor(() => promise); // waits for the axios promise to fulfill

    removes = screen.getAllByText('remove');
    expect(removes.length).toBe(2);
  });

  it('adds a funder to the document', async () => {
    const promise = Promise.resolve({
      status: 200,
      data: {
        id: faker.datatype.number(),
        contributor_name: '',
        contributor_type: 'funder',
        identifier_type: 'crossref_funder_id',
        name_identifier_id: '',
        resource_id: resourceId,
      },
    });

    axios.post.mockImplementationOnce(() => promise);

    render(<Funders
      contributors={contributors}
      resourceId={resourceId}
      createPath={createPath}
      updatePath={updatePath}
      deletePath={deletePath}
      reorderPath={reorderPath}
    />);

    const removes = screen.getAllByText('remove');
    expect(removes.length).toBe(3);

    userEvent.click(screen.getByText('Add another funder'));

    await waitFor(() => {
      expect(screen.getAllByText('remove').length).toBe(4);
    });
  });

  it('Sets no funders', async () => {
    const promise = Promise.resolve({
      status: 200,
      data: {
        id: faker.datatype.number(),
        contributor_name: '',
        contributor_type: 'funder',
        identifier_type: 'crossref_funder_id',
        name_identifier_id: '',
        resource_id: resourceId,
      },
    });
    const nofunder = Promise.resolve({
      status: 200,
      data: {
        id: faker.datatype.number(),
        contributor_name: 'N/A',
        contributor_type: 'funder',
        identifier_type: 'crossref_funder_id',
        name_identifier_id: '0',
        resource_id: resourceId,
      },
    });

    axios.post.mockImplementationOnce(() => promise);

    render(<Funders
      contributors={[]}
      resourceId={resourceId}
      createPath={createPath}
      updatePath={updatePath}
      deletePath={deletePath}
      reorderPath={reorderPath}
    />);

    await waitFor(() => promise); // waits for the axios promise to fulfil

    const removes = screen.getAllByText('remove');
    expect(removes.length).toBe(1);

    axios.patch.mockImplementationOnce(() => nofunder);

    userEvent.click(screen.getByLabelText('No funding received'));
    await waitFor(() => nofunder);
    expect(screen.getByLabelText('No funding received').checked).toEqual(true);
  });
});
