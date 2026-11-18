# Redmine Risks

[![Latest Release](https://img.shields.io/github/release/eXolnet/redmine-risks.svg?style=flat-square)](https://github.com/eXolnet/redmine-risks/releases)
[![Redmine Compatibility](https://img.shields.io/static/v1?label=redmine&message=6.0.x-6.1.x&color=blue&style=flat-square)](https://www.redmine.org/plugins/redmine_risks)
[![Software License](https://img.shields.io/badge/license-MIT-8469ad.svg?style=flat-square)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/eXolnet/redmine_risks/tests.yml?label=tests&style=flat-square)](https://github.com/eXolnet/redmine_risks/actions?query=workflow%3Atests)
[![Maintainability](https://api.codeclimate.com/v1/badges/85dc8be921f40a688900/maintainability)](https://codeclimate.com/github/eXolnet/redmine-risks/maintainability)

Manage the results of the qualitative risk analysis, quantitative risk analysis, and risk response planning.

## Compatibility

This plugin version is compatible only with Redmine 6.0 and later.

## Installation

1. Download the .ZIP archive, extract files and copy the plugin directory to `#{REDMINE_ROOT}/plugins/redmine_risks`.

2. From the directory `#{REDMINE_ROOT}`, install the plugin's dependencies:

    ```bash
    bundle install
    ```

3. Make a backup of your database, then run the following command to update it:

    ```bash
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production NAME=redmine_risks
    ```
    
4. Seed the default risk categories:

    ```bash
    bundle exec rake risks:seed RAILS_ENV=production
    ```
    
5. Restart Redmine.

6. Login and enable the "Risks" module on projects you want to use it.

### Uninstall

1. Remove the plugin's folder from `#{REDMINE_ROOT}/plugins`.

2. Restart Redmine.

## Usage

Enable the "Risks" module on a project and grant the risk permissions (view, add, edit, delete and manage relations) to the appropriate roles.

Risk categories are managed by administrators in *Administration › Enumerations*. Each project can then enable or disable them in the **Risks** tab of its settings (permission *Manage project risk categories*): only the categories active in the project are offered in the risk form, filters and context menu, while existing risks keep their category even once it is disabled.

Custom fields can be added to risks in *Administration » Custom fields » Risks*. They are displayed in the risk form and page, can be used as columns, filters (when "Used as a filter" is checked) and grouping criteria in the risk list, are recorded in the history and can be restricted to some roles.

### Risk dashboard

The "Risk dashboard" link of the risk list (`/projects/:project_id/risks/dashboard`, `view_risks` permission) shows:

- a 5 × 5 probability × impact matrix with the number of open risks per cell, colored by magnitude; each cell links to the risk list filtered on that probability and impact;
- the number of open, closed and rejected risks;
- the top 5 open risks by magnitude;
- the open risks by category and by strategy.

Themes can adjust the magnitude colors by defining the `--risk-color-magnitude-low`, `--risk-color-magnitude-medium`, `--risk-color-magnitude-high` and `--risk-color-magnitude-extreme` CSS variables as RGB triplets (eg. `46, 160, 67`).

### REST API

When the REST API is enabled (*Administration » Settings » API*), risks can be managed with the same authentication methods as the core Redmine API (API key, HTTP Basic). Every endpoint supports the `json` and `xml` formats.

| Method | Endpoint | Description | Permission |
|---|---|---|---|
| `GET` | `/projects/:project_id/risks.json` | List the risks of a project | View risks |
| `POST` | `/projects/:project_id/risks.json` | Create a risk | Add risks |
| `GET` | `/risks/:id.json` | Show a risk | View risks |
| `PUT` | `/risks/:id.json` | Update a risk | Edit risks |
| `DELETE` | `/risks/:id.json` | Delete a risk | Delete risks |
| `POST` | `/risks/:id/issues.json` | Link an issue (`issue_id` parameter) | Manage risk relations |
| `DELETE` | `/risks/:id/issues/:issue_id.json` | Unlink an issue | Manage risk relations |
| `GET` | `/enumerations/risk_categories.json` | List the system risk categories | — |

**Listing** accepts the usual query parameters: `offset`, `limit`, `sort` (eg. `sort=magnitude:desc,id`) and filters such as `status` (`open` by default; use `status=open|closed|rejected` to get every risk), `assigned_to_id`, `author_id`, `category_id`, `strategy` or `cf_<id>` for risk custom fields used as filters.

**Showing** accepts `include=issues,journals` to add the linked issues and the history.

**Creating or updating** expects a `risk` object with the following attributes:

| Attribute | Description |
|---|---|
| `subject` | Required on creation |
| `description`, `treatments`, `lessons` | Free text |
| `category_id` | ID of a risk category |
| `assigned_to_id` | ID of a user or group |
| `probability`, `impact` | Integer from 0 to 100 (25-point steps match the UI levels) |
| `strategy` | `accept`, `mitigate`, `transfer` or `eliminate` |
| `status` | `open`, `closed` or `rejected` (update only) |
| `notes`, `private_notes` | Journal notes (update only) |
| `custom_fields` | Array of `{"id": <custom field id>, "value": <value>}` (only custom fields visible to the user are taken into account) |

Example:

```bash
curl -X POST -H "Content-Type: application/json" -H "X-Redmine-API-Key: $KEY" \
  -d '{"risk": {"subject": "Key supplier delay", "probability": 50, "impact": 75, "strategy": "mitigate"}}' \
  https://redmine.example.com/projects/my-project/risks.json
```

## Testing

Run tests using the following command:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_risks RAILS_ENV=test
```

## Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md) and [CODE OF CONDUCT](CODE_OF_CONDUCT.md) for details.

## Security

If you discover any security related issues, please email security@exolnet.com instead of using the issue tracker.

## Credits

- [Alexandre D'Eschambeault](https://github.com/xel1045)
- [All Contributors](../../contributors)

## License

Copyright © [eXolnet](https://www.exolnet.com). All rights reserved.

This code is licensed under the [MIT license](http://choosealicense.com/licenses/mit/).
Please see the [license file](LICENSE) for more information.
