# SparkleFormation driver for test-kitchen

## Installation

Put this in your Gemfile:
```ruby
gem 'kitchen-sparkleformation', git: 'https://github.com/devkid/kitchen-sparkleformation'
```

and run:
```
$ bundle
```

## Usage

`.kitchen.yml` configuration:

```yaml
driver:
  name: sparkleformation
  stack_name: kitchen-test
  stack_name_random_suffix: true
  sparkle_packs:
    - some_sparkle_pack
  sparkle_template: my_template_name
  upload_template: true
  s3_region: us-west-1
  s3_bucket: some-bucket
  s3_path: cloudformation/kitchen-tmp
  cf_params:
    some_parameter: some_value
  cf_options:
    :disable_rollback: true
```

## Configuration

| Option                     | Description                                                                                                                                                                           | Default Value        | Required?                        |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|----------------------------------|
| `stack_name`               | The name of the CloudFormation stack to create.                                                                                                                                       |                      | yes                              |
| `stack_name_random_suffix` | If true, append a random suffix string to the given stack name.                                                                                                                       | `false`              |                                  |
| `sparkle_path`             | The path to a directory containing your SparkleFormation template files.                                                                                                              | `'sparkleformation'` |                                  |
| `sparkle_template`         | The name of the SparkleFormation template to use.                                                                                                                                     |                      | yes                              |
| `sparkle_state`            | A hash of compile time parameters that are passed to SparkleFormation.                                                                                                                | `{}`                 |                                  |
| `sparkle_packs`            | Array of SparklePacks to load before compiling the template.                                                                                                                          | `[]`                 |                                  |
| `upload_template`          | If true, upload the template to S3. Requires `s3_region`, `s3_bucket`.                                                                                                                | `false`              | `true` if using nested templates |
| `s3_region`                | Region of given S3 bucket.                                                                                                                                                            |                      | if `upload_template` is true     |
| `s3_bucket`                | Name of an S3 bucket where templates are uploaded to.                                                                                                                                 |                      | if `upload_template` is true     |
| `s3_path`                  | Path in the S3 bucket where templates are uploaded to.                                                                                                                                |                      | if `upload_template` is true     |
| `hostname_output`          | Extract the hostname of an instance from the value of the given output.                                                                                                               |                      | no                               |
| `hostname_resource`        | The stack resource to use to extract the hostname from.                                                                                                                               |                      | no                               |
| `hostname_attribute`       | The attribute of a the given stack resource to extract the hostname from. Can be `'<physical_resource_id>'` to use the Physical ID of the given stack resource (e.g. Route53 record). |                      | no                               |
| `cf_params`                | Runtime parameters to pass to CloudFormation stack.                                                                                                                                   | `{}`                 | no                               |
| `cf_options`               | Additional options to pass to CloudFormation stack creation. See [here](http://docs.aws.amazon.com/sdkforruby/api/Aws/CloudFormation/Client.html#create_stack-instance_method).       | `{}`                 | no                               |

If neither `hostname_output` nor `hostname_resource` is given, the first EC2 instance in the stack is used to extract the hostname.

If `hostname_attribute` is set to something other than `'<physical_resource_id>'`, the given `hostname_resource` must be an EC2 instance. See [here](http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#describe_instances-instance_method) for a list of available attributes. By default, `private_ip_address` is used.
