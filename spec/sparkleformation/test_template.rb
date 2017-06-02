SparkleFormation.new(:compute, provider: :aws) do
  AWSTemplateFormatVersion '2010-09-09'
  description 'Sparkle Guide Compute Template'

  parameters do
    sparkle_image_id.type 'String'
    sparkle_ssh_key_name.type 'String'
    sparkle_flavor do
      type 'String'
      default 't2.micro'
      allowed_values ['t2.micro', 't2.small']
    end
  end

  dynamic!(:ec2_instance, :sparkle) do
    properties do
      image_id ref!(:sparkle_image_id)
      instance_type ref!(:sparkle_flavor)
      key_name ref!(:sparkle_ssh_key_name)
    end
  end

  outputs.sparkle_public_address do
    description 'Compute instance public address'
    value attr!(:sparkle_ec2_instance, :public_ip)
  end
end
