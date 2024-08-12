# Redmine Risks

[![Latest Release](https://img.shields.io/github/release/eXolnet/redmine-risks.svg?style=flat-square)](https://github.com/eXolnet/redmine-risks/releases)
[![Redmine Compatibility](https://img.shields.io/static/v1?label=redmine&message=5.0.x-5.1.x&color=blue&style=flat-square)](https://www.redmine.org/plugins/redmine_risks)
[![Software License](https://img.shields.io/badge/license-MIT-8469ad.svg?style=flat-square)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/eXolnet/redmine_risks/tests.yml?label=tests&style=flat-square)](https://github.com/eXolnet/redmine_risks/actions?query=workflow%3Atests)
[![Maintainability](https://api.codeclimate.com/v1/badges/85dc8be921f40a688900/maintainability)](https://codeclimate.com/github/eXolnet/redmine-risks/maintainability)

Manage the results of the qualitative risk analysis, quantitative risk analysis, and risk response planning.

## Compatibility

This plugin version is compatible only with Redmine 5.0 and later.

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

Explain how to use your package.

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

This code is licensed under the [MIT license](http://choosealicense.com/licenses/mit/).
Please see the [license file](LICENSE) for more information.
