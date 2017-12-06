require "kitchen/driver/sparkleformation"
require "aws-sdk"

describe Kitchen::Driver::Sparkleformation do
  let(:state) { {} }

  let(:config) do
    {
      :sparkle_path => "spec/sparkleformation",
      :sparkle_template => "test_template",
      :stack_name => "test-stack"
    }
  end
  let(:driver) { Kitchen::Driver::Sparkleformation.new(config) }
  let(:stack_id) { "arn:aws:cloudformation:us-east-1:27:stack/kit06a57/8f7535" }

  before :each do
    @cf = Aws::CloudFormation::Client.new(stub_responses: true)
    allow(Aws::CloudFormation::Client).to receive(:new).and_return(@cf)

    @ec2 = Aws::EC2::Client.new(stub_responses: true)
    allow(Aws::EC2::Client).to receive(:new).and_return(@ec2)

    @asg = Aws::AutoScaling::Client.new(stub_responses: true)
    allow(Aws::AutoScaling::Client).to receive(:new).and_return(@asg)

    @cf.stub_responses(:describe_stacks, stacks: [
      {
        stack_name: 'abc',
        creation_time: Time.now,
        stack_status: 'CREATE_COMPLETE'
      }
    ])

    @cf.stub_responses(:create_stack, stack_id: stack_id)
    @cf.stub_responses(:list_stack_resources, stack_resource_summaries: 2.times.map { |i|
      {
        resource_type:          'AWS::EC2::Instance',
        logical_resource_id:    "Sparkle#{i}",
        physical_resource_id:   "i-abcdef#{i}",
        resource_status:        'CREATE_COMPLETE',
        last_updated_timestamp: Time.now
      }
    })

    @ec2.stub_responses(:describe_instances, -> (context) {
      {
        reservations: [
          instances: [
            {
              private_ip_address: "10.#{context.params[:instance_ids].first[-1].to_i + 1}.2.3",
              public_ip_address:  "20.#{context.params[:instance_ids].first[-1].to_i + 2}.4.6"
            }
          ]
        ]
      }
    })

    @ec2.stub_responses(:describe_spot_fleet_instances, @ec2.stub_data(:describe_spot_fleet_instances, active_instances: [
      { instance_id: 'i-abcdef0' },
      { instance_id: 'i-1234567' }
    ]))

    @asg.stub_responses(:describe_auto_scaling_groups, @asg.stub_data(:describe_auto_scaling_groups, auto_scaling_groups: [
      {
        instances: [
          { instance_id: 'i-abcdef0' },
          { instance_id: 'i-1234567' }
        ]
      }
    ]))
  end

  describe "#create" do
    it "returns if the stack is already created" do
      state[:stack_id] = stack_id
      state[:hostname] = 'some-hostname'

      expect(@cf).not_to receive(:create_stack)

      driver.create(state)
    end

    it "creates and returns stack if there is none yet" do
      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('10.1.2.3')
    end

    it "uses the given attribute to extract the hostname of the first EC2 instance in the stack" do
      driver = Kitchen::Driver::Sparkleformation.new(config.merge({
        hostname_attribute: 'public_ip_address'
      }))

      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('20.2.4.6')
    end

    it "uses the given resource and attribute to extract the hostname of an EC2 instance" do
      driver = Kitchen::Driver::Sparkleformation.new(config.merge({
        hostname_resource: 'Sparkle1'
      }))

      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('10.2.2.3')
    end

    it "uses the given resource to extract the hostname of the first EC2 instance in an AutoScaling group" do
      @cf.stub_responses(:list_stack_resources, stack_resource_summaries: [
        {
          resource_type:          'AWS::AutoScaling::AutoScalingGroup',
          logical_resource_id:    "Sparkle",
          physical_resource_id:   "i-abcdef",
          resource_status:        'CREATE_COMPLETE',
          last_updated_timestamp: Time.now
        }
      ])

      driver = Kitchen::Driver::Sparkleformation.new(config)

      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('10.1.2.3')
    end

    it "uses the given resource to extract the hostname of the first EC2 instance in a spot fleet" do
      @cf.stub_responses(:list_stack_resources, stack_resource_summaries: [
        {
          resource_type:          'AWS::EC2::SpotFleet',
          logical_resource_id:    "Sparkle",
          physical_resource_id:   "i-abcdef",
          resource_status:        'CREATE_COMPLETE',
          last_updated_timestamp: Time.now
        }
      ])

      driver = Kitchen::Driver::Sparkleformation.new(config)

      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('10.1.2.3')
    end

    it "uses the physical resource id as hostname if configured so" do
      driver = Kitchen::Driver::Sparkleformation.new(config.merge({
        hostname_attribute: '<physical_resource_id>'
      }))

      driver.create(state)

      expect(state[:stack_id]).to eql(stack_id)
      expect(state[:hostname]).to eql('i-abcdef0')
    end
  end
end
