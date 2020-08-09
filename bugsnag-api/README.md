# Bugsnag API filtering script

Based on: https://github.com/Gusto/adams-sandbox/tree/master/bugsnag-api.   
Make sure to update secrets.sh with your key, in the format of `secrets_example.sh`.

## Example: Get event counts over past 60d for transient errors

```
ruby get_all_errors.rb -> Will output: all_errors_output.json
ruby error_data_to_errors_successful_on_retry.rb all_errors_output.json -> Will output: errors_successful_on_retry.json
ruby error_data_to_errors_duplicated_by_retry.rb all_errors_output.json -> Will output: errors_duplicated_by_retry.json
```

Note: `gem install bugsnag-api` may be required!
