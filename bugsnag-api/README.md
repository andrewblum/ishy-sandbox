# Bugsnag API script

Based on: https://github.com/Gusto/adams-sandbox/tree/master/bugsnag-api.   
Make sure to update secrets.json with your key, in the format of `secrets_example.json`.

## Example: Get event counts over past 90d for transient errors

```
ruby get_all_errors.rb >> all_errors_output.json
ruby error_data_to_errors_successful_on_retry.rb output.json >> errors_successful_on_retry.json
```
