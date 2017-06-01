Gem::Specification.new do |s|
  s.name = 'kitchen-sparkleformation'
  s.version = "0.1"
  s.licenses = ['Nonstandard']
  s.homepage = 'https://bitbucket.ops.expertcity.com/projects/RCL/repos/kitchen-sparkleformation'
  s.summary = 'Kitchen driver for SparkleFormation / CloudFormation'
  s.description = 'Kitchen driver for creating CloudFormation stacks using SparkleFormation templates'
  s.authors = ['Alfred Krohmer']
  s.email = 'devkid@gmx.net'
  s.files = %w(README.md kitchen-sparkleformation.gemspec) + Dir['lib/**/*']
  s.add_runtime_dependency 'sparkle_formation', '>= 3', '< 4'
  s.add_runtime_dependency 'aws-sdk', '>= 2', '< 3'
  s.add_dependency 'test-kitchen' 
end
