
Permissions in Dryad
====================

Dryad has several levels of permissions. Some permissions are defined by the
`User.role` field:
- *superuser* -- Has full access to all features in the system. Superusers
  automatically have permissions to do anything that any other type of user can do.
- *curator* -- Has access to most features, though not some that are more
  dangerous and only useful to developers.
- *tenant_curator* -- Has view and edit access to all datasets in the associated
  tenant
- *admin* -- Has view access to all datasets in the associated tenant,
  regardless of publication status.
- *user* -- Has view access to published datasets. Has view and edit access to
  datasets they created.

Other permissions are orthogonal to the `User.role`:
- *journal_admin* -- Has view and edit access to all datasets associated with an
   article in the appropriate journal. Journal administrators are defined by
  `User.journal_role`.
- *funder_admin* -- Has view and edit access to all datasets associated with a
   given funder. Funder administrators are defined by
  `FunderRole`
- *API access* -- All users are able to use the public API without authentication. However,
  some portions of the API require authication. Once a user is
  authenticated through the API, their other permissions take
  effect. To allow a user access to the API, see [Adding API Accounts](../apis/adding_api_accounts.md).

