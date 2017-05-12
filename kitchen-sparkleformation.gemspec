Gem::Specification.new do |s|
  s.name = 'kitchen-sparkleformation'
  s.version = "0.1.0"
  s.licenses = %w(GPL-2.0)
  s.homepage = 'https://github.com/devkid/kitchen-sparkleformation'
  s.summary = 'Kitchen driver for SparkleFormation / CloudFormation'
  s.description = 'Kitchen driver for creating CloudFormation stacks using SparkleFormation templates'
  s.authors = ['Alfred Krohmer']
  s.email = 'devkid@gmx.net'
  s.files = %w(README.md LICENSE.md kitchen-sparkleformation.gemspec Gemfile Gemfile.lock) + Dir['lib/**/*']
  s.add_runtime_dependency 'sparkle_formation', '>= 3', '< 4'
  s.add_runtime_dependency 'aws-sdk', '>= 2', '< 3'
end
