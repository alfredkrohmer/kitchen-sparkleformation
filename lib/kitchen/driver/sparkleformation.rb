require 'aws-sdk'
require 'sparkle_formation'
require 'securerandom'

module Kitchen
  module Driver
    class Sparkleformation < Kitchen::Driver::Base
      default_config :stack_name_random_suffix, false
      default_config :sparkle_path, 'sparkleformation'
      default_config :sparkle_state, {}
      default_config :sparkle_packs, []
      default_config :upload_template, false
      default_config :cf_options, {}
      default_config :cf_params, {}
      default_config :hostname_output, nil
      default_config :hostname_resource, nil
      default_config :hostname_attribute, nil

      def initialize(config)
        init_config config
        @cf = Aws::CloudFormation::Client.new
      end

      def create(state)
        unless state[:stack_id].nil?
          # will fail if the stack does not exist:
          @stack_desc = @cf.describe_stacks(stack_name: state[:stack_id]).stacks.first

          case @stack_desc.stack_status
          when 'CREATE_IN_PROGRESS'
            @cf.wait_until :stack_create_complete, stack_name: state[:stack_id]
          when 'CREATE_COMPLETE'
          else
            raise "Invalid stack state: #{@stack_desc.stack_status}"
          end

          if state[:hostname].nil?
            state[:hostname] = hostname(state[:stack_id])
          end

          return
        end

        # generate stack name
        @stack_name = config[:stack_name]
        if config[:stack_name_random_suffix]
          @stack_name << "-#{SecureRandom.hex(6)}"
        end

        json = generate_cloudformation_template

        if config[:upload_template]
          url = upload_template @stack_name, json
        end

        # build options for call to create_stack
        stack_options = {
          stack_name:   @stack_name,
          parameters:   config[:cf_params].map { |k, v| { parameter_key: SparkleFormation.camel(k), parameter_value: v } }
        }
        if config[:upload_template]
          stack_options[:template_url] = url
        else
          stack_options[:template_body] = json.to_json
        end
        stack_options.merge! config[:cf_options]

        info 'Triggering CloudFormation stack creation'
        state[:stack_id] = @cf.create_stack(stack_options).stack_id

        info "Waiting for stack #{state[:stack_id]} to reach state CREATE_COMPLETE..."
        @cf.wait_until :stack_create_complete, stack_name: state[:stack_id]
        info 'Stack creation finished'

        state[:hostname] = hostname(state[:stack_id])
      end

      def destroy(state)
        return if state[:stack_id].nil?

        info 'Triggering CloudFormation stack deletion'
        @cf.delete_stack stack_name: state[:stack_id]

        info 'Waiting for stack to reach state DELETE_COMPLETE...'
        @cf.wait_until :stack_delete_complete, stack_name: state[:stack_id]

        info 'Stack deletion finished'
      end

      private

      def generate_cloudformation_template
        info 'Generating CloudFormation template'

        SparkleFormation.sparkle_path = config[:sparkle_path]

        formation                     = SparkleFormation.compile(config[:sparkle_template], :sparkle)
        config[:sparkle_packs].each do |pack|
          require pack
          formation.sparkle.add_sparkle SparkleFormation::SparklePack.new name: pack
        end
        formation.compile state: config[:sparkle_state]

        # nesting
        formation.apply_nesting do |stack_name, nested_stack_sfn, original_stack_resource|
          unless config[:upload_template]
            raise 'Nested stacks require template upload'
          end

          info "Generating nested stack template for #{stack_name}"
          dump = nested_stack_sfn.compile.dump!

          url = upload_template "#{@stack_name}-#{stack_name}", dump

          # update original stack
          original_stack_resource.properties.delete!(:stack)
          original_stack_resource.properties.set!('TemplateURL', url)
        end

        formation.dump
      end

      def upload_template(stack_name, json)
        raise 's3_region not given' if config[:s3_region].nil?
        raise 's3_bucket not given' if config[:s3_bucket].nil?
        path = "#{config[:s3_path]}/#{stack_name}.json"
        info "Uploading CloudFormation template to s3://#{config[:s3_bucket]}/#{path}"
        s3_client = Aws::S3::Client.new(region: config[:s3_region])
        bucket = Aws::S3::Resource.new(client: s3_client).bucket(config[:s3_bucket])
        bucket.put_object(
          key:  path,
          body: json.to_json
        ).public_url
      end

      def stack_resources(stack_id)
        resources  = []
        next_token = nil
        loop do
          response  = @cf.list_stack_resources(stack_name: stack_id, next_token: next_token)
          resources += response.stack_resource_summaries
          break if (next_token = response.next_token).nil?
        end
        resources
      end

      def hostname(stack_id)
        unless config[:hostname_output].nil?
          @stack_desc ||= @cf.describe_stacks(stack_name: state[:stack_id]).stacks.first
          output = @stack_desc.outputs.find { |o| o.output_key == config[:hostname_output] }
          raise "Output »#{config[:hostname_output]}« not found in stack" if output.nil?
          return output.output_value
        end

        resources = stack_resources stack_id

        if config[:hostname_resource].nil?
          resource = resources.find { |r| r.resource_type == 'AWS::EC2::Instance' }
          raise 'Stack does not contain an EC2 instance' if resource.nil?
        else
          resource = resources.find { |r| r.logical_resource_id == config[:hostname_resource] }
          raise "Resource »#{config[:hostname_resource]}« not found in stack" if resource.nil?
        end

        if config[:hostname_attribute] == '<physical_resource_id>'
          return resource.physical_resource_id
        end

        unless resource.resource_type == 'AWS::EC2::Instance'
          raise "Resource »#{config[:hostname_resource]}« is not of type AWS::EC2::Instance"
        end

        ec2 = Aws::EC2::Client.new
        instance = ec2.describe_instances(instance_ids: [resource.physical_resource_id]).reservations.first.instances.first

        if config[:hostname_attribute].nil?
          instance.private_ip_address
        else
          instance.send(config[:hostname_attribute].to_sym)
        end
      end
    end
  end
end
